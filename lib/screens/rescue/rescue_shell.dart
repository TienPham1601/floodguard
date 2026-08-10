import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../widgets/app_map.dart';
import 'unit_profile_screen.dart';
import 'rescue_list_tab.dart';
import '../../data/firebase_service.dart';

class RescueShell extends StatefulWidget {
  const RescueShell({super.key});
  @override
  State<RescueShell> createState() => _RescueShellState();
}

class _RescueShellState extends State<RescueShell> {
  int _idx = 0;
  LatLng _myPos = const LatLng(21.0285, 105.8542);
  
  final GlobalKey<RescueListTabState> _listTabKey = GlobalKey<RescueListTabState>();
  StreamSubscription? _watchSub;
  final Set<String> _notifiedIds = {};

  @override
  void initState() {
    super.initState();
    Geolocator.getCurrentPosition().then((p) {
      if (mounted) setState(() => _myPos = LatLng(p.latitude, p.longitude));
    });
    _initAgreementWatcher();
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }

  void _initAgreementWatcher() {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;

    // Việc 2: Đặt Listener ở màn cha RescueShell để sống suốt phiên làm việc
    _watchSub = FirebaseService.db.collection('sos_requests')
        .where('rescuerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        final doc = change.doc;
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'];
        final id = doc.id;

        debugPrint('WATCH: docId=$id status=$status rescuerId=${data['rescuerId']} type=${change.type}');

        if (change.type == DocumentChangeType.modified) {
          if (status == 'accepted' && !_notifiedIds.contains(id)) {
            _notifiedIds.add(id);
            _handleAgreementSuccess(data['vehiclePlate'] ?? 'xe');
          } else if (status == 'pending' && data['rescuerId'] == null) {
            _handleDeclineNotice();
          }
        }
      }
    });
  }

  void _handleAgreementSuccess(String plate) {
    HapticFeedback.mediumImpact();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('Khách hàng ($plate) ĐÃ ĐỒNG Ý báo giá của bạn!')),
        ]),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Tự động chuyển sang tab "Cứu hộ" (index 1) và sub-tab "Đang xử lý" (index 1)
    setState(() => _idx = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listTabKey.currentState?.switchTab(1);
    });
  }

  void _handleDeclineNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chủ xe đã từ chối báo giá của bạn.'), backgroundColor: Colors.orange),
    );
    // Chuyển về danh sách yêu cầu mới
    setState(() => _idx = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listTabKey.currentState?.switchTab(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: [
        AppMap(center: _myPos, markers: const [], isRescuerMode: true),
        RescueListTab(key: _listTabKey, myPos: _myPos),
        const UnitProfileScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: C.surface(context),
        indicatorColor: C.brandBg(context),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Bản đồ'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Cứu hộ'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}
