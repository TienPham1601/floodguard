import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

class VehicleData {
  String id;
  String plate;
  String model;
  int waterCm;
  int tempC;
  int warnAt;
  int dangerAt;
  String? type;

  VehicleData({
    required this.id,
    required this.plate,
    required this.model,
    this.waterCm = 0,
    this.tempC = 25,
    this.warnAt = 20,
    this.dangerAt = 40,
    this.type,
  });

  factory VehicleData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleData(
      id: doc.id,
      plate: (data['plate'] ?? '').toString(),
      model: (data['model'] ?? '').toString(),
      waterCm: (data['waterCm'] as num?)?.toInt() ?? 0,
      tempC: (data['tempC'] as num?)?.toInt() ?? 25,
      warnAt: (data['warnAt'] as num?)?.toInt() ?? 20,
      dangerAt: (data['dangerAt'] as num?)?.toInt() ?? 40,
      type: data['type']?.toString(),
    );
  }
}

class FloodReport {
  final String id;
  final double latitude;
  final double longitude;
  final int waterCm;
  final DateTime reportedAt;
  final String source;
  final String? photoThumb;
  final String? description;
  final String? reporterId;

  FloodReport({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.waterCm,
    required this.reportedAt,
    required this.source,
    this.photoThumb,
    this.description,
    this.reporterId,
  });

  factory FloodReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FloodReport(
      id: doc.id,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      waterCm: data['waterCm'] ?? 0,
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] ?? 'user',
      photoThumb: data['photoThumb'],
      description: data['description'],
      reporterId: data['reporterId'],
    );
  }
}

class SOSRequest {
  final String id;
  final String requesterId;
  final String? vehicleId;
  final String vehiclePlate;
  final String vehicleModel;
  final double latitude;
  final double longitude;
  final int waterCm;
  final String status;
  final DateTime createdAt;
  final String? rescuerId;
  final String? garageName;

  SOSRequest({
    required this.id,
    required this.requesterId,
    this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleModel,
    required this.latitude,
    required this.longitude,
    required this.waterCm,
    required this.status,
    required this.createdAt,
    this.rescuerId,
    this.garageName,
  });

  factory SOSRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SOSRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      vehicleId: data['vehicleId'],
      vehiclePlate: data['vehiclePlate'] ?? '',
      vehicleModel: data['vehicleModel'] ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      waterCm: data['waterCm'] ?? 0,
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rescuerId: data['rescuerId'],
      garageName: data['garageName'],
    );
  }
}

class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static Stream<User?> get authStateChanges => auth.authStateChanges().doOnData((user) {
    if (user != null) {
      cleanupExpiredSOS();
    } else {
      _sosSubject.add(null);
    }
  });

  // --- QUẢN LÝ SOS THEO XE & DỌN DẸP ---
  static final _sosSubject = BehaviorSubject<SOSRequest?>();
  static SOSRequest? get cachedSOS => _sosSubject.valueOrNull;
  static Stream<SOSRequest?> get currentVehicleSosStream => _sosSubject.stream;

  static StreamSubscription? _currentVehicleSosSub;

  static void listenToVehicleSOS(String vehicleId) {
    final user = auth.currentUser;
    if (user == null) return;

    _currentVehicleSosSub?.cancel();
    debugPrint('FIREBASE_SOS: Listening for Vehicle: $vehicleId');
    _currentVehicleSosSub = db.collection('sos_requests')
        .where('requesterId', isEqualTo: user.uid) // CẦN THIẾT CHO SECURITY RULES
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['pending', 'accepted', 'processing', 'expanded', 'timeout'])
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final docs = snap.docs.map((d) => SOSRequest.fromFirestore(d)).toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs.first;
        })
        .listen((sos) => _sosSubject.add(sos));
  }

  static void initSOSListener() {
    cleanupExpiredSOS();
  }

  static Future<int> cleanupExpiredSOS() async {
    final user = auth.currentUser;
    if (user == null) return 0;
    final now = DateTime.now();
    final limit = now.subtract(const Duration(minutes: 7));
    try {
      final snap = await db.collection('sos_requests')
          .where('requesterId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();
      int count = 0;
      final batch = db.batch();
      for (var doc in snap.docs) {
        final ct = (doc.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        if (ct.isBefore(limit)) {
          batch.update(doc.reference, {'status': 'timeout'});
          count++;
        }
      }
      if (count > 0) await batch.commit();
      return count;
    } catch (e) {
      debugPrint('FIREBASE_SOS_CLEANUP_ERROR: $e');
      return 0;
    }
  }

  // --- XÁC THỰC ---
  static Future<void> login(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _translateError(e.code);
    }
  }

  static Future<void> logout() async {
    _currentVehicleSosSub?.cancel();
    _sosSubject.add(null);
    await auth.signOut();
  }

  static Future<void> register({
    required String email, 
    required String password, 
    required String fullName,
    String? phone,
    String role = 'driver',
    String? garageCode,
  }) async {
    try {
      String? garageId;
      String? garageName;
      if (role == 'rescuer') {
        final gSnap = await db.collection('garages').where('garageCode', isEqualTo: garageCode).limit(1).get();
        if (gSnap.docs.isEmpty) throw 'Mã đơn vị không hợp lệ.';
        garageId = gSnap.docs.first.id;
        garageName = gSnap.docs.first.data()['garageName'];
      }
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      await db.collection('users').doc(cred.user!.uid).set({
        'name': fullName, 'email': email, 'phone': phone, 'role': role,
        'garageId': garageId, 'garageName': garageName, 'serviceRadius': 15,
        'deviceSetupDone': false, 'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw _translateError(e.code);
    }
  }

  static String _translateError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Email đã tồn tại.';
      case 'invalid-email': return 'Email không hợp lệ.';
      case 'weak-password': return 'Mật khẩu quá yếu.';
      case 'user-not-found': return 'Tài khoản không tồn tại.';
      case 'wrong-password': return 'Sai mật khẩu.';
      default: return 'Lỗi hệ thống ($code).';
    }
  }

  // --- QUẢN LÝ XE & SOS ---
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final u = auth.currentUser;
    if (u == null) return null;
    final doc = await db.collection('users').doc(u.uid).get();
    return doc.data();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile() {
    return db.collection('users').doc(auth.currentUser!.uid).snapshots();
  }

  static Future<void> selectVehicle(String id) async {
    final u = auth.currentUser;
    if (u == null) return;
    await db.collection('users').doc(u.uid).update({'selectedVehicleId': id});
    listenToVehicleSOS(id);
  }

  static Future<void> addVehicle({required String model, required String plate, int clearance = 20, String type = 'Sedan'}) async {
    final u = auth.currentUser;
    if (u == null) return;
    final doc = await db.collection('vehicles').add({
      'ownerId': u.uid, 'model': model, 'plate': plate, 'type': type,
      'waterCm': 0, 'tempC': 25, 'warnAt': clearance, 'dangerAt': clearance + 20,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await selectVehicle(doc.id);
  }

  static Future<void> deleteVehicle(String id) async => await db.collection('vehicles').doc(id).delete();

  static Stream<VehicleData?> streamCurrentVehicle() {
    final u = auth.currentUser;
    if (u == null) return Stream.value(null);
    return db.collection('users').doc(u.uid).snapshots().asyncMap((userDoc) async {
      final sid = userDoc.data()?['selectedVehicleId'];
      if (sid != null) {
        final doc = await db.collection('vehicles').doc(sid).get();
        if (doc.exists) return VehicleData.fromFirestore(doc);
      }
      final snap = await db.collection('vehicles').where('ownerId', isEqualTo: u.uid).limit(1).get();
      return snap.docs.isEmpty ? null : VehicleData.fromFirestore(snap.docs.first);
    });
  }

  static Stream<List<VehicleData>> streamAllUserVehicles() {
    final u = auth.currentUser;
    if (u == null) return Stream.value([]);
    return db.collection('vehicles').where('ownerId', isEqualTo: u.uid).snapshots().map((s) => s.docs.map((d) => VehicleData.fromFirestore(d)).toList());
  }

  static Stream<List<FloodReport>> streamFloodReports() {
    final cut = DateTime.now().subtract(const Duration(hours: 8));
    return db.collection('flood_reports').where('reportedAt', isGreaterThan: cut).snapshots().map((s) => s.docs.map((d) => FloodReport.fromFirestore(d)).toList());
  }

  static Stream<List<SOSRequest>> streamActiveSOS() {
    // Luồng này dành cho cứu hộ, xem mọi đơn.
    return db.collection('sos_requests').where('status', isNotEqualTo: 'done').snapshots().map((s) => s.docs.map((d) => SOSRequest.fromFirestore(d)).toList());
  }

  static Future<void> createSOS({required String vehicleId, required String plate, required String model, required double lat, required double lng, required int waterCm}) async {
    final u = auth.currentUser;
    if (u == null) return;
    
    // Đóng đơn pending cũ của chính xe này (SỬA LỖI QUERY THIẾU REQUESTERID)
    final old = await db.collection('sos_requests')
        .where('requesterId', isEqualTo: u.uid)
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'pending')
        .get();
        
    if (old.docs.isNotEmpty) {
      final b = db.batch();
      for(var d in old.docs) b.update(d.reference, {'status': 'timeout'});
      await b.commit();
    }
    
    final doc = await db.collection('sos_requests').add({
      'requesterId': u.uid, 'vehicleId': vehicleId, 'vehiclePlate': plate, 'vehicleModel': model,
      'latitude': lat, 'longitude': lng, 'waterCm': waterCm, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp(),
    });
    final newDoc = await doc.get();
    if (newDoc.exists) _sosSubject.add(SOSRequest.fromFirestore(newDoc));
  }

  static Future<void> acceptSOS(String id, String rid, String gname) async {
    await db.collection('sos_requests').doc(id).update({'status': 'accepted', 'rescuerId': rid, 'garageName': gname});
  }

  static Future<void> updateSOSStatus(String id, String status) async {
    await db.collection('sos_requests').doc(id).update({'status': status});
    if (status == 'done' || status == 'cancelled') _sosSubject.add(null);
  }

  static Future<void> cancelSOS(String id) async => await updateSOSStatus(id, 'cancelled');

  static Future<List<SOSRequest>> getRecentSOS({int limit = 5}) async {
    final u = auth.currentUser;
    if (u == null) return [];
    // QUERY NÀY ĐÃ CÓ REQUESTERID
    final s = await db.collection('sos_requests').where('requesterId', isEqualTo: u.uid).orderBy('createdAt', descending: true).limit(limit).get();
    return s.docs.map((d) => SOSRequest.fromFirestore(d)).toList();
  }

  static Future<void> deleteSOSRequest(String id) async => await db.collection('sos_requests').doc(id).delete();
  
  static Future<void> addFloodReport({required double lat, required double lng, required int waterCm, String? photoBase64, String? description}) async {
    final user = auth.currentUser;
    await db.collection('flood_reports').add({
      'latitude': lat, 'longitude': lng, 'waterCm': waterCm, 'reportedAt': FieldValue.serverTimestamp(),
      'source': 'user', 'photoThumb': photoBase64, 'description': description, 'reporterId': user?.uid,
    });
  }

  static Future<void> completeSetup() async => await db.collection('users').doc(auth.currentUser!.uid).update({'deviceSetupDone': true});
  static Future<void> updateServiceRadius(int r) async => await db.collection('users').doc(auth.currentUser!.uid).update({'serviceRadius': r});
  static Future<void> changePassword(String cp, String np) async {
    final u = auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: u.email!, password: cp);
    await u.reauthenticateWithCredential(cred);
    await u.updatePassword(np);
  }
}
