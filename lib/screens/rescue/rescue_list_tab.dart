import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
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
  State<RescueListTab> createState() => RescueListTabState();
}

class RescueListTabState extends State<RescueListTab> with SingleTickerProviderStateMixin {
  late final Stream<List<SOSRequest>> _newStream;
  late final Stream<List<SOSRequest>> _activeStream;
  late TabController _tabController;
  
  double _radius = 15.0;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Khởi tạo stream MỘT LẦN duy nhất trong initState (Fix Lỗi 1)
    _newStream = FirebaseService.streamActiveSOS(isRescuer: true);
    _activeStream = FirebaseService.streamProcessingSOS();
    
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void switchTab(int index) {
    if (mounted) _tabController.animateTo(index);
  }

  Future<void> _initData() async {
    final prof = await FirebaseService.getUserProfile();
    if (mounted) {
      setState(() {
        _radius = (prof?['serviceRadius'] as num?)?.toDouble() ?? 15.0;
        _loadingProfile = false;
      });
    }
    FirebaseService.cleanupExpiredSOS();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều hành cứu hộ'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: C.brand(context),
          labelStyle: T.title(context).copyWith(fontSize: 14),
          tabs: const [
            Tab(text: 'Yêu cầu mới'),
            Tab(text: 'Đang xử lý'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _List(status: 'pending', myPos: widget.myPos, radius: _radius, stream: _newStream),
          _List(status: 'active', myPos: widget.myPos, radius: _radius, stream: _activeStream),
        ],
      ),
    );
  }
}

class _List extends StatefulWidget {
  final String status;
  final LatLng myPos;
  final double radius;
  final Stream<List<SOSRequest>> stream;
  
  const _List({required this.status, required this.myPos, required this.radius, required this.stream});

  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> with AutomaticKeepAliveClientMixin {
  bool _hasInitialData = false;
  Timer? _timeoutTimer;
  bool _isTimedOut = false;

  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _isTimedOut = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_hasInitialData) {
        setState(() => _isTimedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return StreamBuilder<List<SOSRequest>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        // Log debug theo yêu cầu (Việc 1 - Bước 1)
        if (widget.status == 'active') {
          debugPrint('PROCESSING: connState=${snapshot.connectionState} hasData=${snapshot.hasData} hasError=${snapshot.hasError} docs=${snapshot.data?.length}');
          if (snapshot.hasError) debugPrint('PROCESSING ERROR: ${snapshot.error}');
        }

        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 16),
                Text('Lỗi tải dữ liệu: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                AppButton('Thử lại', tone: Tone.soft, full: false, onTap: () {
                  setState(() { _hasInitialData = false; _isTimedOut = false; });
                  _startTimeout();
                }),
              ],
            ),
          ));
        }

        if (snapshot.hasData) {
          _hasInitialData = true;
          return _buildContent(snapshot.data!);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_isTimedOut) return _buildEmptyState();
          return const Center(child: CircularProgressIndicator());
        }

        return _buildEmptyState();
      },
    );
  }

  Widget _buildContent(List<SOSRequest> allRequests) {
    var list = List<SOSRequest>.from(allRequests);
    
    if (widget.status == 'pending') {
      // Tab yêu cầu mới: lọc đơn chưa nhận/mới báo giá
      list = list.where((r) => ['pending', 'expanded', 'quoted'].contains(r.status)).toList();
      if (widget.myPos.latitude != 0) {
        list = list.where((r) {
          final d = Geolocator.distanceBetween(widget.myPos.latitude, widget.myPos.longitude, r.latitude, r.longitude) / 1000;
          return d <= widget.radius;
        }).toList();
      }
    } else {
      // Tab đang xử lý: FirebaseService.streamProcessingSOS đã lọc rescuerId và status active
      // list = list; // Giữ nguyên kết quả từ stream
    }

    if (list.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (c, i) => widget.status == 'pending' 
        ? _SOSCard(req: list[i], myPos: widget.myPos)
        : _ActiveTaskCard(req: list[i], myPos: widget.myPos),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade200),
      const SizedBox(height: 12),
      Text(
        widget.status == 'pending' ? 'Chưa có yêu cầu cứu hộ nào.' : 'Bạn chưa nhận yêu cầu nào.', 
        style: const TextStyle(color: Colors.grey)
      ),
      if (_isTimedOut && !_hasInitialData) 
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Đang đợi phản hồi từ máy chủ...', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        )
    ]));
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

  @override
  void initState() {
    super.initState();
    _calcRoute();
    _startLocationSharing();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 45), (t) {
      if (!_isDisposed) _calcRoute();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationTimer?.cancel();
    _routeRefreshTimer?.cancel();
    super.dispose();
  }

  void _startLocationSharing() {
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
    final req = widget.req;
    final bool isArrived = req.status == 'arrived';
    final bool isProcessing = req.status == 'processing';

    final bool isKm = _distText?.contains('km') ?? true;
    final String distLabel = isKm ? 'km còn lại' : 'còn lại';
    final String timeVal = _timeText?.replaceAll(' phút', '') ?? '...';
    final String timeDisplay = (timeVal == '0' || timeVal == '...') ? 'dưới 1' : timeVal;

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
            _statItem(distLabel, _distText ?? '...'),
            Container(width: 1, height: 30, color: Colors.blue.shade100),
            _statItem('phút nữa tới', timeDisplay),
          ]),
        ),

        const SizedBox(height: 32),
        Text('TIẾN ĐỘ CỨU HỘ', style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 20),

        _step(1, 'Đã nhận yêu cầu', time: req.acceptedAt, done: true),
        _step(2, 'Đang di chuyển', time: req.movingAt, done: req.movingAt != null, active: isProcessing, sub: 'đang chia sẻ vị trí cho chủ xe'),
        _step(3, 'Đã tới hiện trường', time: req.arrivedAt, done: req.arrivedAt != null, active: isArrived),
        _step(4, 'Hoàn tất', time: req.doneAt, done: req.status == 'done', last: true),

        const SizedBox(height: 32),
        
        Row(children: [
          Expanded(child: AppButton('Gọi', icon: Icons.phone, tone: Tone.ghost, onTap: () => callPhone(context, req.requesterPhone ?? ''))),
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
