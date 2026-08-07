import 'dart:async';
import 'package:flutter/material.dart';
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
  final String? rescuerName;
  final String? rescuerPhone;
  final String? garageName;
  final String? requesterName;
  final String? requesterPhone;
  
  final bool? powerCut;
  final bool? intakeClosed;
  final bool? personInside;
  final double? waterRisingSpeed;

  final DateTime? acceptedAt;
  final DateTime? movingAt;
  final DateTime? arrivedAt;
  final DateTime? doneAt;
  final DateTime? quotedAt;
  final DateTime? agreedAt;

  final double? rescuerLat;
  final double? rescuerLng;

  final int? quotedPrice;
  final String? quoteNote;

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
    this.rescuerName,
    this.rescuerPhone,
    this.garageName,
    this.requesterName,
    this.requesterPhone,
    this.powerCut,
    this.intakeClosed,
    this.personInside,
    this.waterRisingSpeed,
    this.acceptedAt,
    this.movingAt,
    this.arrivedAt,
    this.doneAt,
    this.quotedAt,
    this.agreedAt,
    this.rescuerLat,
    this.rescuerLng,
    this.quotedPrice,
    this.quoteNote,
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
      rescuerName: data['rescuerName'],
      rescuerPhone: data['rescuerPhone'],
      garageName: data['garageName'],
      requesterName: data['requesterName'],
      requesterPhone: data['requesterPhone'],
      powerCut: data['powerCut'],
      intakeClosed: data['intakeClosed'],
      personInside: data['personInside'],
      waterRisingSpeed: (data['waterRisingSpeed'] as num?)?.toDouble(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      movingAt: (data['movingAt'] as Timestamp?)?.toDate(),
      arrivedAt: (data['arrivedAt'] as Timestamp?)?.toDate(),
      doneAt: (data['doneAt'] as Timestamp?)?.toDate(),
      quotedAt: (data['quotedAt'] as Timestamp?)?.toDate(),
      agreedAt: (data['agreedAt'] as Timestamp?)?.toDate(),
      rescuerLat: (data['rescuerLat'] as num?)?.toDouble(),
      rescuerLng: (data['rescuerLng'] as num?)?.toDouble(),
      quotedPrice: data['quotedPrice'] as int?,
      quoteNote: data['quoteNote'],
    );
  }
}

class SOSQuote {
  final String id;
  final String rescuerId;
  final String rescuerName;
  final String rescuerPhone;
  final String garageName;
  final int price;
  final String note;
  final DateTime quotedAt;
  final double rating;
  final int ratingCount;

  SOSQuote({
    required this.id,
    required this.rescuerId,
    required this.rescuerName,
    required this.rescuerPhone,
    required this.garageName,
    required this.price,
    required this.note,
    required this.quotedAt,
    this.rating = 0.0,
    this.ratingCount = 0,
  });

  factory SOSQuote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SOSQuote(
      id: doc.id,
      rescuerId: data['rescuerId'] ?? '',
      rescuerName: data['rescuerName'] ?? '',
      rescuerPhone: data['rescuerPhone'] ?? '',
      garageName: data['garageName'] ?? '',
      price: data['price'] ?? 0,
      note: data['note'] ?? '',
      quotedAt: (data['quotedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rating: (data['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: data['ratingCount'] ?? 0,
    );
  }
}

class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static Stream<User?> get authStateChanges => auth.authStateChanges().doOnData((user) {
    if (user != null) cleanupExpiredSOS();
    else _sosSubject.add(null);
  });

  static final _sosSubject = BehaviorSubject<SOSRequest?>();
  static SOSRequest? get cachedSOS => _sosSubject.valueOrNull;
  static Stream<SOSRequest?> get currentVehicleSosStream => _sosSubject.stream;

  static StreamSubscription? _currentVehicleSosSub;

  static void listenToVehicleSOS(String vehicleId) {
    final user = auth.currentUser;
    if (user == null) return;
    _currentVehicleSosSub?.cancel();
    _currentVehicleSosSub = db.collection('sos_requests')
        .where('requesterId', isEqualTo: user.uid)
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['pending', 'quoted', 'accepted', 'processing', 'arrived', 'expanded', 'timeout'])
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final docs = snap.docs.map((d) => SOSRequest.fromFirestore(d)).toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs.first;
        })
        .listen((sos) => _sosSubject.add(sos));
  }

  static const Duration pendingTimeout = Duration(minutes: 7);
  static const Duration acceptedTimeout = Duration(hours: 2);

  static Future<int> cleanupExpiredSOS() async {
    final user = auth.currentUser;
    if (user == null) return 0;
    final now = DateTime.now();
    try {
      final pendingSnap = await db.collection('sos_requests').where('requesterId', isEqualTo: user.uid).where('status', isEqualTo: 'pending').get();
      int count = 0;
      final batch = db.batch();
      for (var doc in pendingSnap.docs) {
        final ct = (doc.data()['createdAt'] as Timestamp?)?.toDate() ?? now;
        if (now.difference(ct) > pendingTimeout) {
          batch.update(doc.reference, {'status': 'timeout'});
          _addIncidentLog(user.uid, doc.id, 'timeout', doc.data()['vehiclePlate'], 'Yêu cầu cứu hộ hết thời gian chờ.');
          count++;
        }
      }
      final staleSnap = await db.collection('sos_requests').where('requesterId', isEqualTo: user.uid).where('status', whereIn: ['accepted', 'processing', 'arrived']).get();
      for (var doc in staleSnap.docs) {
        final at = (doc.data()['acceptedAt'] as Timestamp?)?.toDate() ?? now;
        if (now.difference(at) > acceptedTimeout) {
          batch.update(doc.reference, {'status': 'timeout'});
          _addIncidentLog(user.uid, doc.id, 'timeout', doc.data()['vehiclePlate'], 'Yêu cầu quá hạn (2 giờ).');
          count++;
        }
      }
      if (count > 0) await batch.commit();
      return count;
    } catch (e) { return 0; }
  }

  static Future<void> login(String email, String password) async {
    try { await auth.signInWithEmailAndPassword(email: email, password: password); }
    on FirebaseAuthException catch (e) { throw _translateError(e.code); }
  }

  static Future<void> logout() async {
    _currentVehicleSosSub?.cancel();
    _sosSubject.add(null);
    await auth.signOut();
  }

  static Future<void> register({required String email, required String password, required String fullName, String? phone, String role = 'driver', String? garageCode}) async {
    try {
      String? garageId, garageName;
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
    } on FirebaseAuthException catch (e) { throw _translateError(e.code); }
  }

  static String _translateError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Email đã tồn tại.';
      case 'invalid-email': return 'Email không hợp lệ.';
      case 'weak-password': return 'Mật khẩu quá yếu.';
      default: return 'Lỗi hệ thống ($code).';
    }
  }

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
    final doc = await db.collection('vehicles').add({'ownerId': u.uid, 'model': model, 'plate': plate, 'type': type, 'waterCm': 0, 'tempC': 25, 'warnAt': clearance, 'dangerAt': clearance + 20, 'createdAt': FieldValue.serverTimestamp()});
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

  static Stream<List<SOSRequest>> streamActiveSOS({bool isRescuer = false}) {
    final user = auth.currentUser;
    if (user == null) return Stream.value([]);
    Query<Map<String, dynamic>> query = db.collection('sos_requests');
    if (!isRescuer) query = query.where('requesterId', isEqualTo: user.uid);
    return query.snapshots().map((snap) {
      final docs = snap.docs.map((d) => SOSRequest.fromFirestore(d)).toList();
      return docs.where((r) => ['pending', 'quoted', 'accepted', 'processing', 'arrived', 'expanded'].contains(r.status)).toList();
    });
  }

  static Stream<List<SOSRequest>> streamProcessingSOS() {
    final user = auth.currentUser;
    if (user == null) return Stream.value([]);
    return db.collection('sos_requests')
        .where('rescuerId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) => SOSRequest.fromFirestore(d)).toList();
      return docs.where((r) => ['accepted', 'processing', 'arrived'].contains(r.status)).toList();
    });
  }

  static Future<void> createSOS({required String vehicleId, required String plate, required String model, required double lat, required double lng, required int waterCm}) async {
    final u = auth.currentUser;
    if (u == null) return;
    final prof = await getUserProfile();
    final String rName = prof?['name'] ?? u.displayName ?? u.email?.split('@')[0] ?? 'Chủ xe';
    final old = await db.collection('sos_requests').where('requesterId', isEqualTo: u.uid).where('vehicleId', isEqualTo: vehicleId).where('status', isEqualTo: 'pending').get();
    if (old.docs.isNotEmpty) {
      final b = db.batch();
      for(var d in old.docs) b.update(d.reference, {'status': 'timeout'});
      await b.commit();
    }
    final doc = await db.collection('sos_requests').add({
      'requesterId': u.uid, 'vehicleId': vehicleId, 'vehiclePlate': plate, 'vehicleModel': model,
      'latitude': lat, 'longitude': lng, 'waterCm': waterCm, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp(),
      'requesterName': rName, 'requesterPhone': prof?['phone'],
    });
    await _addIncidentLog(u.uid, doc.id, 'pending', plate, 'Đã gửi yêu cầu cứu hộ khẩn cấp tại mực nước ${waterCm}cm.');
    final newDoc = await doc.get();
    if (newDoc.exists) _sosSubject.add(SOSRequest.fromFirestore(newDoc));
  }

  static Stream<List<SOSQuote>> streamQuotes(String sosId) {
    return db.collection('sos_requests').doc(sosId).collection('quotes').orderBy('quotedAt', descending: true).snapshots().map((s) => s.docs.map((d) => SOSQuote.fromFirestore(d)).toList());
  }

  static Future<void> sendQuote({required String sosId, required int price, String note = ''}) async {
    final user = auth.currentUser;
    if (user == null) return;
    final prof = await getUserProfile();
    final quoteData = {
      'rescuerId': user.uid, 'rescuerName': prof?['name'] ?? 'Thợ cứu hộ', 'rescuerPhone': prof?['phone'] ?? '',
      'garageName': prof?['garageName'] ?? 'Gara', 'price': price, 'note': note, 'quotedAt': FieldValue.serverTimestamp(),
      'ratingAvg': (prof?['ratingAvg'] as num?)?.toDouble() ?? 0.0, 'ratingCount': prof?['ratingCount'] ?? 0,
    };
    debugPrint('FIREBASE_QUOTE: Sending to sos_requests/$sosId/quotes/${user.uid} with data: $quoteData');
    final batch = db.batch();
    batch.set(db.collection('sos_requests').doc(sosId).collection('quotes').doc(user.uid), quoteData);
    batch.update(db.collection('sos_requests').doc(sosId), {
      'status': 'quoted', 'rescuerId': user.uid, 'rescuerName': prof?['name'] ?? 'Thợ cứu hộ',
      'rescuerPhone': prof?['phone'] ?? '', 'garageName': prof?['garageName'] ?? 'Gara',
      'quotedPrice': price, 'quoteNote': note, 'quotedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> acceptQuote(String sosId, SOSQuote quote) async {
    await db.collection('sos_requests').doc(sosId).update({
      'status': 'accepted', 'rescuerId': quote.rescuerId, 'rescuerName': quote.rescuerName,
      'rescuerPhone': quote.rescuerPhone, 'garageName': quote.garageName, 'quotedPrice': quote.price,
      'quoteNote': quote.note, 'acceptedAt': FieldValue.serverTimestamp(), 'agreedAt': FieldValue.serverTimestamp(),
    });
    final snap = await db.collection('sos_requests').doc(sosId).get();
    if (snap.exists) _addIncidentLog(snap.data()!['requesterId'], sosId, 'accepted', snap.data()!['vehiclePlate'], 'Chủ xe đã đồng ý báo giá từ ${quote.garageName}.');
  }

  static Future<void> declineQuote(String sosId, String rescuerId) async {
    await db.collection('sos_requests').doc(sosId).collection('quotes').doc(rescuerId).delete();
    final quotes = await db.collection('sos_requests').doc(sosId).collection('quotes').get();
    if (quotes.docs.isEmpty) await db.collection('sos_requests').doc(sosId).update({'status': 'pending'});
  }

  static Future<void> acceptSOS(String id, String rid, String gname) async {
    final user = auth.currentUser;
    if (user == null) return;
    final prof = await getUserProfile();
    final String rName = prof?['name'] ?? 'Thợ cứu hộ';
    final String rPhone = prof?['phone'] ?? '';
    debugPrint('FIREBASE_ACCEPT: id=$id rid=$rid gname=$gname');
    return db.runTransaction((transaction) async {
      final docRef = db.collection('sos_requests').doc(id);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw 'Yêu cầu không tồn tại.';
      final currentStatus = snapshot.data()?['status'];
      if (currentStatus != 'pending' && currentStatus != 'expanded') throw 'ALREADY_TAKEN';
      transaction.update(docRef, {'status': 'accepted', 'rescuerId': rid, 'rescuerName': rName, 'rescuerPhone': rPhone, 'garageName': gname, 'acceptedAt': FieldValue.serverTimestamp()});
      final reqData = snapshot.data()!;
      _addIncidentLog(reqData['requesterId'], id, 'accepted', reqData['vehiclePlate'], 'Đơn vị $gname đã tiếp nhận yêu cầu.');
    });
  }

  static Future<void> updateSOSStatus(String id, String status) async {
    final Map<String, dynamic> updates = {'status': status};
    if (status == 'processing') updates['movingAt'] = FieldValue.serverTimestamp();
    if (status == 'arrived') updates['arrivedAt'] = FieldValue.serverTimestamp();
    if (status == 'done') updates['doneAt'] = FieldValue.serverTimestamp();
    await db.collection('sos_requests').doc(id).update(updates);
    final snap = await db.collection('sos_requests').doc(id).get();
    if (snap.exists) {
      final req = SOSRequest.fromFirestore(snap);
      await _addIncidentLog(req.requesterId, id, status, req.vehiclePlate, _getStatusMessage(status, req.garageName));
    }
    if (status == 'done' || status == 'cancelled') _sosSubject.add(null);
  }

  static String _getStatusMessage(String status, String? garage) {
    switch (status) {
      case 'accepted': return 'Đơn vị $garage đã tiếp nhận yêu cầu.';
      case 'processing': return 'Cứu hộ đang di chuyển tới hiện trường.';
      case 'arrived': return 'Cứu hộ đã tới vị trí xe.';
      case 'done': return 'Hoàn tất quá trình cứu hộ.';
      case 'cancelled': return 'Yêu cầu cứu hộ đã bị hủy.';
      default: return 'Trạng thái thay đổi: $status';
    }
  }

  static Future<void> _addIncidentLog(String ownerId, String sosId, String status, String plate, String message) async {
    await db.collection('incident_logs').add({'ownerId': ownerId, 'sosId': sosId, 'status': status, 'vehiclePlate': plate, 'timestamp': FieldValue.serverTimestamp(), 'message': message});
  }

  static Future<void> updateRescuerLocation(String id, double lat, double lng) async {
    await db.collection('sos_requests').doc(id).update({'rescuerLat': lat, 'rescuerLng': lng});
  }

  static Future<void> cancelSOSByRescuer(String id) async {
    final snap = await db.collection('sos_requests').doc(id).get();
    if (snap.exists) _addIncidentLog(snap.data()!['requesterId'], id, 'pending', snap.data()!['vehiclePlate'], 'Cứu hộ đã hủy nhận đơn.');
    await db.collection('sos_requests').doc(id).update({'status': 'pending', 'rescuerId': null, 'rescuerName': null, 'rescuerPhone': null, 'garageName': null, 'acceptedAt': null, 'movingAt': null, 'arrivedAt': null, 'rescuerLat': null, 'rescuerLng': null, 'quotedPrice': null, 'quoteNote': null});
  }

  static Future<void> cancelSOS(String id) async => await updateSOSStatus(id, 'cancelled');

  static Stream<SOSRequest?> streamSOSDetail(String id) {
    return db.collection('sos_requests').doc(id).snapshots().map((doc) => doc.exists ? SOSRequest.fromFirestore(doc) : null);
  }

  static Future<void> submitRating({required String sosId, required String rescuerId, required double stars, String comment = '', List<String> tags = const []}) async {
    final user = auth.currentUser;
    if (user == null) return;
    await db.collection('ratings').add({'sosId': sosId, 'rescuerId': rescuerId, 'requesterId': user.uid, 'stars': stars, 'comment': comment, 'tags': tags, 'createdAt': FieldValue.serverTimestamp()});
    final thSnap = await db.collection('users').doc(rescuerId).get();
    if (thSnap.exists) {
      final d = thSnap.data()!;
      double currentAvg = (d['ratingAvg'] as num?)?.toDouble() ?? 0.0;
      int currentCount = d['ratingCount'] ?? 0;
      double newAvg = ((currentAvg * currentCount) + stars) / (currentCount + 1);
      await db.collection('users').doc(rescuerId).update({'ratingAvg': newAvg, 'ratingCount': currentCount + 1});
    }
  }

  static Future<void> addFloodReport({required double lat, required double lng, required int waterCm, String? photoBase64, String? description}) async {
    final user = auth.currentUser;
    final doc = await db.collection('flood_reports').add({'latitude': lat, 'longitude': lng, 'waterCm': waterCm, 'reportedAt': FieldValue.serverTimestamp(), 'source': 'user', 'photoThumb': photoBase64, 'description': description, 'reporterId': user?.uid});
    if (user != null) {
      final vSnap = await streamAllUserVehicles().first;
      final plate = vSnap.isNotEmpty ? vSnap.first.plate : '---';
      await _addIncidentLog(user.uid, doc.id, 'report', plate, 'Báo cáo điểm ngập ${waterCm}cm.');
    }
  }

  static Future<void> updateServiceRadius(int r) async => await db.collection('users').doc(auth.currentUser!.uid).update({'serviceRadius': r});

  static Future<void> completeSetup() async => await db.collection('users').doc(auth.currentUser!.uid).update({'deviceSetupDone': true});

  static Future<List<SOSRequest>> getRecentSOS({int limit = 5}) async {
    final u = auth.currentUser;
    if (u == null) return [];
    final s = await db.collection('sos_requests').where('requesterId', isEqualTo: u.uid).orderBy('createdAt', descending: true).limit(limit).get();
    return s.docs.map((d) => SOSRequest.fromFirestore(d)).toList();
  }

  static Future<void> deleteSOSRequest(String id) async => await db.collection('sos_requests').doc(id).delete();

  static Future<void> changePassword(String cp, String np) async {
    final u = auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: u.email!, password: cp);
    await u.reauthenticateWithCredential(cred);
    await u.updatePassword(np);
  }

  static Future<void> forceCloseStuckSOS() async {
    final user = auth.currentUser;
    if (user == null) return;
    final prof = await getUserProfile();
    final role = prof?['role'] ?? 'driver';
    Query<Map<String, dynamic>> query = db.collection('sos_requests').where('status', whereIn: ['pending', 'accepted', 'processing', 'arrived', 'expanded']);
    if (role == 'rescuer') query = query.where('rescuerId', isEqualTo: user.uid);
    else query = query.where('requesterId', isEqualTo: user.uid);
    final snap = await query.get();
    final batch = db.batch();
    for(var doc in snap.docs) batch.update(doc.reference, {'status': 'timeout'});
    await batch.commit();
    _sosSubject.add(null);
  }
}
