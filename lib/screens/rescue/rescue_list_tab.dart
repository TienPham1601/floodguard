import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../utils.dart';
import '../../data/firebase_service.dart';
import '../../data/directions.dart';
import 'request_detail_screen.dart';

class RescueListTab extends StatefulWidget {
  final LatLng myPos;
  const RescueListTab({super.key, required this.myPos});

  @override
  State<RescueListTab> createState() => _RescueListTabState();
}

class _RescueListTabState extends State<RescueListTab> {
  late Stream<List<SOSRequest>> _sosStream;
  double _radius = 15.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Khởi tạo stream một lần duy nhất (Việc 3b)
    _sosStream = FirebaseService.streamActiveSOS(isRescuer: true);
    _initData();
  }

  Future<void> _initData() async {
    final prof = await FirebaseService.getUserProfile();
    if (mounted) {
      setState(() {
        _radius = (prof?['serviceRadius'] as num?)?.toDouble() ?? 15.0;
        _loading = false;
      });
    }
    FirebaseService.cleanupExpiredSOS();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Điều hành cứu hộ'),
          bottom: TabBar(
            indicatorColor: C.brand(context),
            labelStyle: T.title(context).copyWith(fontSize: 14),
            tabs: const [
              Tab(text: 'Yêu cầu mới'),
              Tab(text: 'Đang xử lý'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _List(status: 'pending', myPos: widget.myPos, radius: _radius, stream: _sosStream),
          _List(status: 'active', myPos: widget.myPos, radius: _radius, stream: _sosStream),
        ]),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final String status;
  final LatLng myPos;
  final double radius;
  final Stream<List<SOSRequest>> stream;
  
  const _List({required this.status, required this.myPos, required this.radius, required this.stream});

  @override
  Widget build(BuildContext context) {
    debugPrint('LIST build: status=$status'); // Việc 3 - Debug build
    return StreamBuilder<List<SOSRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        // Việc 3a, 3c: Xử lý loading và rỗng chuẩn xác
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Lỗi kết nối: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          ));
        }
        
        var list = snapshot.data ?? [];
        final user = FirebaseAuth.instance.currentUser;
        
        if (status == 'pending') {
          list = list.where((r) => ['pending', 'expanded', 'quoted'].contains(r.status)).toList();
          if (myPos.latitude != 0) {
            list = list.where((r) {
              final d = Geolocator.distanceBetween(myPos.latitude, myPos.longitude, r.latitude, r.longitude) / 1000;
              return d <= radius;
            }).toList();
          }
        } else {
          list = list.where((r) => (r.status == 'accepted' || r.status == 'processing' || r.status == 'arrived') && r.rescuerId == user?.uid).toList();
        }

        if (list.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text(status == 'pending' ? 'Chưa có yêu cầu cứu hộ nào.' : 'Bạn chưa nhận yêu cầu nào.', style: const TextStyle(color: Colors.grey)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (c, i) => status == 'pending' 
            ? _SOSCard(req: list[i], myPos: myPos)
            : _ActiveTaskCard(req: list[i], myPos: myPos),
        );
      },
    );
  }
}

class _ActiveTaskCard extends StatefulWidget {
  final SOSRequest req;
  final LatLng myPos;
  const _ActiveTaskCard({required this.req, required this.myPos});

  @override
  State<_ActiveTaskCard> createState() => _ActiveTaskCardState();
}

class _ActiveTaskCardState extends State<_ActiveTaskCard> {
  String? _distText;
  String? _timeText;
  Timer? _locationTimer;
  Timer? _routeRefreshTimer;
  LatLng? _lastCalculatedPos;
  bool _isDisposed = false;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _calcRoute();
    _startTracking();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 45), (t) {
      if (!_isDisposed) _calcRoute();
    });

    // Việc 2: Lắng nghe realtime trạng thái đơn để đồng bộ khi user hủy
    _statusSub = FirebaseService.db.collection('sos_requests').doc(widget.req.id).snapshots().listen((snap) {
      if (!snap.exists || snap.data()?['status'] == 'cancelled' || snap.data()?['status'] == 'timeout') {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Yêu cầu đã bị hủy hoặc hết hiệu lực.'), backgroundColor: Colors.orange)
           );
         }
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _startTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 20), (t) async {
      if (widget.req.status == 'processing' && !_isDisposed) {
        try {
          final p = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
          FirebaseService.updateRescuerLocation(widget.req.id, p.latitude, p.longitude);
        } catch (_) {}
      }
    });
  }

  Future<void> _calcRoute() async {
    if (['arrived', 'done'].contains(widget.req.status)) return;
    if (_lastCalculatedPos != null) {
      final d = Geolocator.distanceBetween(widget.myPos.latitude, widget.myPos.longitude, _lastCalculatedPos!.latitude, _lastCalculatedPos!.longitude);
      if (d < 100 && _distText != null) return;
    }

    final route = await RoutingService.fetchRoute(widget.myPos, LatLng(widget.req.latitude, widget.req.longitude));
    if (mounted && route != null && !_isDisposed) {
      setState(() {
        _distText = route.distanceText;
        _timeText = route.durationText;
        _lastCalculatedPos = widget.myPos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('PROCESSING build: ${DateTime.now().millisecondsSinceEpoch}');
    final req = widget.req;
    final bool isArrived = req.status == 'arrived';
    final bool isProcessing = req.status == 'processing';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C.brandBg(context), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.directions_car, color: C.brand(context)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req.vehiclePlate, style: T.title(context).copyWith(fontSize: 22, letterSpacing: 1)),
            Text('${req.requesterName ?? "Chủ xe"} · ${req.vehicleModel}', style: T.caption(context)),
          ])),
          Text('#${req.id.substring(0,6).toUpperCase()}', style: T.mono(context, Colors.grey).copyWith(fontSize: 12)),
        ]),
        
        const SizedBox(height: 24),
        
        if (!isArrived) Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statItem('km còn lại', _distText ?? '...'),
            Container(width: 1, height: 30, color: Colors.blue.shade100),
            _statItem('phút nữa tới', _timeText?.replaceAll(' phút', '') ?? '...'),
          ]),
        ),

        const SizedBox(height: 32),
        Text('TIẾN ĐỘ CỨU HỘ', style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 20),

        _step(1, 'Đã nhận yêu cầu', time: req.acceptedAt, done: true),
        _step(2, 'Đang di chuyển', time: req.movingAt, done: req.movingAt != null, active: isProcessing, sub: 'đang chia sẻ vị trí cho chủ xe'),
        _step(3, 'Đã tới hiện trường', time: req.arrivedAt, done: req.arrivedAt != null, active: isArrived),
        _step(4, 'Hoàn tất', last: true),

        const SizedBox(height: 32),
        
        Row(children: [
          Expanded(child: AppButton('Gọi chủ xe', icon: Icons.phone, tone: Tone.ghost, onTap: () => callPhone(context, req.requesterPhone ?? ''))),
          const SizedBox(width: 12),
          if (!isArrived) 
            Expanded(flex: 2, child: AppButton(isProcessing ? 'Đã tới nơi' : 'Bắt đầu di chuyển', 
                onTap: () => FirebaseService.updateSOSStatus(req.id, isProcessing ? 'arrived' : 'processing')))
          else
            Expanded(flex: 2, child: AppButton('Hoàn tất cứu hộ', tone: Tone.brand, onTap: () => FirebaseService.updateSOSStatus(req.id, 'done'))),
        ]),
        
        const SizedBox(height: 12),
        AppButton('Dẫn đường trên bản đồ', icon: Icons.navigation, tone: Tone.soft, onTap: () {
          ORSNavigation.target.value = MapTarget(name: req.vehiclePlate, subtitle: req.vehicleModel, pos: LatLng(req.latitude, req.longitude));
          DefaultTabController.of(context).animateTo(0);
        }),
        
        const SizedBox(height: 12),
        Center(child: TextButton(onPressed: () => _confirmCancel(context, req.id), child: Text('Hủy nhận yêu cầu', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))),
      ]),
    );
  }

  Widget _statItem(String label, String val) => Column(children: [
    Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.blue)),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w500)),
  ]);

  Widget _step(int n, String title, {DateTime? time, bool done = false, bool active = false, bool last = false, String? sub}) {
    final color = active || done ? Colors.blue : Colors.grey.shade300;
    return IntrinsicHeight(
      child: Row(children: [
        Column(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? Colors.blue : Colors.white, border: Border.all(color: color, width: 2)),
            child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : Center(child: Text('$n', style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold))),
          ),
          if (!last) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.3))),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: TextStyle(fontWeight: active || done ? FontWeight.bold : FontWeight.normal, color: active ? Colors.blue : (done ? null : Colors.grey))),
              const Spacer(),
              if (time != null) Text(DateFormat('HH:mm').format(time), style: T.caption(context)),
            ]),
            if (sub != null && active) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blue))),
            if (!last) const SizedBox(height: 24),
          ]),
        )
      ]),
    );
  }

  void _confirmCancel(BuildContext context, String id) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Hủy nhận đơn?'), content: const Text('Đơn sẽ được quay lại hàng chờ cho thợ khác.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hủy ngay', style: TextStyle(color: Colors.red)))]));
    if (ok == true) FirebaseService.cancelSOSByRescuer(id);
  }
}

class _SOSCard extends StatelessWidget {
  final SOSRequest req;
  final LatLng myPos;
  const _SOSCard({required this.req, required this.myPos});

  @override
  Widget build(BuildContext context) {
    final dist = Geolocator.distanceBetween(myPos.latitude, myPos.longitude, req.latitude, req.longitude) / 1000;
    
    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(id: req.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StatusTag(req.status == 'quoted' ? 'ĐANG CHỜ PHẢN HỒI' : 'YÊU CẦU MỚI', 
                  bg: req.status == 'quoted' ? Colors.blue.shade50 : Colors.red.shade50, 
                  fg: req.status == 'quoted' ? Colors.blue : Colors.red),
              const Spacer(),
              Text(DateFormat('HH:mm, dd/MM').format(req.createdAt), style: T.caption(context)),
            ]),
            const SizedBox(height: 16),
            Text('${req.vehiclePlate.substring(0,3)}-***.**', style: T.h2(context).copyWith(letterSpacing: 1)),
            Text(req.vehicleModel, style: T.body(context)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(child: Text('Toạ độ: ${req.latitude.toStringAsFixed(4)}, ${req.longitude.toStringAsFixed(4)}', style: T.small(context))),
              Text('${dist.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ]),
            const Divider(height: 32),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mực nước hiện tại', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('${req.waterCm} cm', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
              ]),
              const Spacer(),
              AppButton('Xem chi tiết', full: false, height: 40, onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(id: req.id)));
              }),
            ]),
          ]),
        ),
      ),
    );
  }
}
