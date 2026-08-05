import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
// Removed unused: import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import '../../data/places.dart';

class RescueListTab extends StatelessWidget {
  final LatLng myPos;
  const RescueListTab({super.key, required this.myPos});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý cứu hộ'),
          bottom: TabBar(
            indicatorColor: C.brand(context),
            labelStyle: T.title(context).copyWith(fontSize: 14),
            tabs: const [
              Tab(text: 'Yêu cầu mới'),
              Tab(text: 'Đang xử lý'),
            ],
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: FirebaseService.getUserProfile(),
          builder: (c, profSnap) {
            final radius = (profSnap.data?['serviceRadius'] as num?)?.toDouble() ?? 15.0;
            return TabBarView(children: [
              _List(status: 'pending', myPos: myPos, radius: radius),
              _List(status: 'active', myPos: myPos, radius: radius),
            ]);
          }
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final String status;
  final LatLng myPos;
  final double radius;
  const _List({required this.status, required this.myPos, required this.radius});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SOSRequest>>(
      stream: FirebaseService.streamActiveSOS(isRescuer: true), // SỬA: Phải truyền isRescuer: true
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        var list = snapshot.data ?? [];
        final user = FirebaseAuth.instance.currentUser;
        debugPrint('RESCUE_LIST: Snapshot received. Total count=${list.length}');
        
        if (status == 'pending') {
          list = list.where((r) => r.status == 'pending' || r.status == 'expanded').toList();
        } else {
          list = list.where((r) => (r.status == 'accepted' || r.status == 'processing') && r.rescuerId == user?.uid).toList();
        }

        // --- LỌC BÁN KÍNH AN TOÀN ---
        bool isPosAvailable = myPos.latitude != 0 && myPos.longitude != 0;
        if (isPosAvailable) {
          list = list.where((r) {
            final d = Geolocator.distanceBetween(myPos.latitude, myPos.longitude, r.latitude, r.longitude) / 1000;
            debugPrint('RESCUE_LIST: Dist to ${r.id} = ${d.toStringAsFixed(1)}km (Limit: ${radius}km)');
            return d <= radius;
          }).toList();
        }

        if (list.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(status == 'pending' ? 'Không có yêu cầu mới.' : 'Bạn chưa có đơn nào đang xử lý.', style: const TextStyle(color: Colors.grey)),
            if (!isPosAvailable && status == 'pending')
               const Padding(padding: EdgeInsets.all(16), child: Text('Chưa lấy được vị trí GPS. Hiển thị mọi yêu cầu.', style: TextStyle(color: Colors.orange, fontSize: 12))),
            if (isPosAvailable && status == 'pending')
               Text('Phạm vi: ${radius.toStringAsFixed(0)}km', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (c, i) => _SOSCard(req: list[i], myPos: myPos),
        );
      },
    );
  }
}

class _SOSCard extends StatelessWidget {
  final SOSRequest req;
  final LatLng myPos;
  const _SOSCard({required this.req, required this.myPos});

  void _sendInsuranceReport(BuildContext context, Map<String, dynamic>? rescuerProfile) {
     final body = '''
YÊU CẦU BỒI THƯỜNG BẢO HIỂM - SỰ CỐ NGẬP LỤT
--------------------------------------------
Thông tin phương tiện:
- Model: ${req.vehicleModel}
- Biển số: ${req.vehiclePlate}

Thông tin sự cố:
- Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(req.createdAt)}
- Vị trí: ${req.latitude}, ${req.longitude}
- Mực nước ghi nhận: ${req.waterCm} cm

Đơn vị cứu hộ: ${rescuerProfile?['garageName'] ?? 'Chưa xác định'}
Thợ xử lý: ${rescuerProfile?['name'] ?? 'Chưa xác định'}
--------------------------------------------
FloodGuard System - Bảo vệ xe khỏi ngập lụt
''';

     Share.share(body, subject: 'Báo cáo bảo hiểm - Xe ${req.vehiclePlate}');
  }

  @override
  Widget build(BuildContext context) {
    final dist = Geolocator.distanceBetween(myPos.latitude, myPos.longitude, req.latitude, req.longitude) / 1000;
    final isPending = req.status == 'pending';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusTag(
            isPending ? 'YÊU CẦU MỚI' : (req.status == 'accepted' ? 'ĐANG TỚI' : 'ĐANG XỬ LÝ'),
            bg: isPending ? Colors.red.shade50 : Colors.blue.shade50,
            fg: isPending ? Colors.red : Colors.blue,
          ),
          const Spacer(),
          Text(DateFormat('HH:mm, dd/MM').format(req.createdAt), style: T.caption(context)),
        ]),
        const SizedBox(height: 16),
        Text(req.vehiclePlate, style: T.h2(context)),
        Text(req.vehicleModel, style: T.body(context)),
        const SizedBox(height: 12),
        FutureBuilder<String>(
          future: SearchService.reverseGeocode(req.latitude, req.longitude),
          builder: (c, snap) => Row(children: [
            Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Expanded(child: Text(snap.data ?? '...', style: T.small(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${dist.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
        const Divider(height: 32),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mực nước tại xe', style: T.caption(context)),
            Text('${req.waterCm} cm', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
          ]),
          const Spacer(),
          if (isPending)
            AppButton('Tiếp nhận', full: false, height: 40, onTap: () async {
              final prof = await FirebaseService.getUserProfile();
              FirebaseService.acceptSOS(req.id, FirebaseAuth.instance.currentUser!.uid, prof?['garageName'] ?? 'Gara');
            })
          else ...[
            if (req.status == 'accepted')
              AppButton('Bắt đầu xử lý', tone: Tone.soft, full: false, height: 40, onTap: () => FirebaseService.updateSOSStatus(req.id, 'processing'))
            else
              Row(children: [
                IconButton(icon: const Icon(Icons.share, color: Colors.blue), onPressed: () async {
                   final prof = await FirebaseService.getUserProfile();
                   _sendInsuranceReport(context, prof);
                }),
                const SizedBox(width: 8),
                AppButton('Hoàn thành', tone: Tone.brand, full: false, height: 40, onTap: () => FirebaseService.updateSOSStatus(req.id, 'done')),
              ]),
          ]
        ]),
      ]),
    );
  }
}
