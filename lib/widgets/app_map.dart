import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme.dart';
import '../ui.dart';
import '../data/location_service.dart';
import '../data/firebase_service.dart';
import '../data/prediction_service.dart';
import '../data/directions.dart';
import '../data/places.dart';
import '../screens/driver/flood_report_screen.dart';
import '../screens/rescue/request_detail_screen.dart';
import '../screens/rescue/quote_input_screen.dart';

class AppMap extends StatefulWidget {
  final LatLng center;
  final List<fm.Marker> markers;
  final MapTarget? target;
  final VoidCallback? onClearTarget;
  final Widget? topOverlay;
  final Widget? bottomOverlay;
  final List<Widget> sideButtons;
  final bool isSearchActive;
  final bool isRescuerMode;

  const AppMap({
    super.key,
    required this.center,
    required this.markers,
    this.target,
    this.onClearTarget,
    this.topOverlay,
    this.bottomOverlay,
    this.sideButtons = const [],
    this.isSearchActive = false,
    this.isRescuerMode = false,
  });

  @override
  State<AppMap> createState() => AppMapState();
}

class AppMapState extends State<AppMap> {
  final fm.MapController _mapController = fm.MapController();
  final FlutterTts _tts = FlutterTts();
  
  LatLng? _currentPos;
  double _currentHeading = 0;
  double _currentSpeed = 0;
  
  List<RiskZone> _riskZones = [];
  WeatherData? _weather;
  RouteResult? _currentRoute;
  
  bool _isNavigating = false;
  bool _isMuted = false;
  bool _legendExpanded = false;
  bool _loadingRoute = false;
  
  Timer? _debounceTimer;
  StreamSubscription<Position>? _positionStream;
  
  int _currentStepIdx = 0;
  String _nextInstruction = "";

  @override
  void initState() {
    super.initState();
    _initMap();
    _tts.setLanguage("vi-VN");
    ORSNavigation.target.addListener(_onExternalNavigationRequest);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _positionStream?.cancel();
    _tts.stop();
    ORSNavigation.target.removeListener(_onExternalNavigationRequest);
    super.dispose();
  }

  void _onExternalNavigationRequest() {
    if (mounted && ORSNavigation.target.value != null) {
      _loadSmartRoute();
    }
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target == null && oldWidget.target != null) _clearRoute();
    if (widget.target != null && (oldWidget.target == null || widget.target?.pos != oldWidget.target?.pos)) {
      _loadSmartRoute();
    }
  }

  void _setNavigating(bool val, String reason) {
    if (_isNavigating != val) {
      debugPrint('NAV_STATE: Changed to $val. Reason: $reason');
      setState(() => _isNavigating = val);
    }
  }

  void _clearRoute() {
    setState(() { 
      _currentRoute = null; 
      _currentSpeed = 0; 
    });
    _setNavigating(false, 'Clear route');
    _positionStream?.cancel();
    _mapController.rotate(0);
    if (_currentPos != null) _mapController.move(_currentPos!, 14.5);
  }

  Future<void> _initMap() async {
    final pos = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _currentPos = pos);
      if (pos != null) {
        _mapController.move(pos, 14.5);
        _refreshWeather(pos);
        _updateRiskZones();
      }
    }
  }

  void _onCameraChange(fm.MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 700), () => _updateRiskZones());
    }
  }

  Future<void> _refreshWeather(LatLng pos) async {
    final w = await PredictionService.getLiveWeather(pos);
    if (mounted) setState(() => _weather = w);
  }

  Future<void> _updateRiskZones() async {
    final bounds = _mapController.camera.visibleBounds;
    final zones = await PredictionService.getRiskZonesFixed(bounds.southWest, bounds.northEast);
    if (mounted) setState(() => _riskZones = zones);
  }

  Future<void> _loadSmartRoute() async {
    final MapTarget? currentTarget = widget.target ?? ORSNavigation.target.value;
    if (currentTarget == null || _currentPos == null) return;
    
    setState(() => _loadingRoute = true);
    try {
      final List<List<LatLng>> avoidPolys = _riskZones.where((z) => z.riskLevel > 0.65).map((z) {
        const d = 0.0018;
        return [LatLng(z.center.latitude - d, z.center.longitude - d), LatLng(z.center.latitude + d, z.center.longitude - d), LatLng(z.center.latitude + d, z.center.longitude + d), LatLng(z.center.latitude - d, z.center.longitude + d), LatLng(z.center.latitude - d, z.center.longitude - d)];
      }).toList();
      
      final route = await RoutingService.fetchRoute(_currentPos!, currentTarget.pos, avoidPolygons: avoidPolys);
      if (mounted) {
        setState(() { _currentRoute = route; _loadingRoute = false; _currentStepIdx = 0; });
        if (route != null) {
          _fitBounds(route.points);
          // VIỆC 1: KHÔNG tự động bật dẫn đường cho rescuer khi load route nữa.
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _startNavigation() {
    if (_currentRoute == null) return;
    _setNavigating(true, 'Explicit start');
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)).listen((p) {
      if (!mounted) return;
      final latlng = LatLng(p.latitude, p.longitude);
      
      if (_currentRoute != null) {
        final nearest = _getNearestPointOnRoute(latlng, _currentRoute!.points);
        final dist = Geolocator.distanceBetween(latlng.latitude, latlng.longitude, nearest.latitude, nearest.longitude);
        if (dist > 50) {
          _loadSmartRoute();
        }

        // VIỆC 2: TỰ NHẬN BIẾT ĐÃ TỚI NƠI (< 100m)
        final MapTarget? target = widget.target ?? ORSNavigation.target.value;
        if (target != null) {
          final distToTarget = Geolocator.distanceBetween(latlng.latitude, latlng.longitude, target.pos.latitude, target.pos.longitude);
          if (distToTarget < 100 && _isNavigating && widget.isRescuerMode) {
             _checkArrivedPrompt(target.pos);
          }
        }
      }

      setState(() { _currentPos = latlng; _currentHeading = p.heading; _currentSpeed = p.speed * 3.6; });
      _mapController.rotate(360 - p.heading);
      _mapController.move(latlng, 18.0); 
      _updateNav(latlng);

      if (widget.isRescuerMode) {
        _updateRescuerGPSInFirestore(latlng);
      }
    });
  }

  DateTime? _lastArrivedPrompt;
  void _checkArrivedPrompt(LatLng targetPos) async {
    if (_lastArrivedPrompt != null && DateTime.now().difference(_lastArrivedPrompt!).inMinutes < 2) return;
    
    _lastArrivedPrompt = DateTime.now();
    HapticFeedback.vibrate();
    
    final arrived = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bạn đã tới hiện trường?'),
        content: const Text('Hệ thống nhận thấy bạn đã ở rất gần vị trí xe cần cứu hộ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Chưa tới')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đã tới nơi')),
        ],
      ),
    );

    if (arrived == true) {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final snap = await FirebaseService.db.collection('sos_requests')
            .where('rescuerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'processing')
            .limit(1).get();
        if (snap.docs.isNotEmpty) {
          await FirebaseService.updateSOSStatus(snap.docs.first.id, 'arrived');
          _clearRoute();
        }
      }
    }
  }

  LatLng _getNearestPointOnRoute(LatLng p, List<LatLng> route) {
    if (route.isEmpty) return p;
    LatLng best = route.first;
    double minD = double.infinity;
    for (var pt in route) {
      final d = Geolocator.distanceBetween(p.latitude, p.longitude, pt.latitude, pt.longitude);
      if (d < minD) { minD = d; best = pt; }
    }
    return best;
  }

  void _updateRescuerGPSInFirestore(LatLng pos) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;
    final snap = await FirebaseService.db.collection('sos_requests')
        .where('rescuerId', isEqualTo: user.uid)
        .where('status', whereIn: ['accepted', 'processing', 'arrived'])
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      FirebaseService.updateRescuerLocation(snap.docs.first.id, pos.latitude, pos.longitude);
    }
  }

  void _updateNav(LatLng p) {
    if (_currentRoute == null || _currentRoute!.steps.isEmpty) return;
    final step = _currentRoute!.steps[_currentStepIdx];
    final d = Geolocator.distanceBetween(p.latitude, p.longitude, step.point.latitude, step.point.longitude);
    if (d < 35 && _currentStepIdx < _currentRoute!.steps.length - 1) {
      setState(() { _currentStepIdx++; _nextInstruction = _currentRoute!.steps[_currentStepIdx].instruction; });
      if (!_isMuted) _tts.speak(_nextInstruction);
    } else {
      setState(() => _nextInstruction = "${step.instruction} sau ${d.round()}m");
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    _mapController.fitCamera(fm.CameraFit.bounds(bounds: fm.LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(85)));
  }

  void moveTo(LatLng p, {double zoom = 15}) => _mapController.move(p, zoom);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        fm.FlutterMap(
          mapController: _mapController,
          options: fm.MapOptions(
            initialCenter: widget.center,
            initialZoom: 14.5,
            onPositionChanged: (pos, hasGesture) => _onCameraChange(_mapController.camera, hasGesture),
          ),
          children: [
            fm.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.newcar', tileProvider: CancellableNetworkTileProvider()),
            fm.CircleLayer(
              circles: _riskZones.map((z) {
                final Color baseColor = z.riskLevel > 0.7 ? Colors.red : (z.riskLevel > 0.5 ? Colors.orange : Colors.yellow);
                return fm.CircleMarker(point: z.center, radius: 120, useRadiusInMeter: true, color: baseColor.withValues(alpha: 0.2), borderColor: baseColor.withValues(alpha: 0.05), borderStrokeWidth: 50);
              }).toList(),
            ),
            StreamBuilder<List<SOSRequest>>(
              stream: FirebaseService.streamActiveSOS(isRescuer: widget.isRescuerMode),
              builder: (c, snap) {
                final requests = snap.data ?? [];
                final List<List<SOSRequest>> clusters = [];
                const double clusterDistanceThreshold = 0.0005;
                for (var r in requests) {
                  bool added = false;
                  for (var cluster in clusters) {
                    final first = cluster.first;
                    final dist = sqrt(pow(r.latitude - first.latitude, 2) + pow(r.longitude - first.longitude, 2));
                    if (dist < clusterDistanceThreshold) { cluster.add(r); added = true; break; }
                  }
                  if (!added) clusters.add([r]);
                }
                return fm.MarkerLayer(markers: clusters.map((cluster) {
                  final r = cluster.first;
                  final count = cluster.length;
                  return fm.Marker(
                    point: LatLng(r.latitude, r.longitude),
                    width: 60, height: 60,
                    child: GestureDetector(
                      onTap: () => count > 1 ? _showSOSList(cluster) : _showSOSDetail(r),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          IgnorePointer(child: Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.5))).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1,1), end: const Offset(2.2, 2.2), duration: const Duration(seconds: 2), curve: Curves.easeOut).fade(begin: 0.5, end: 0, duration: const Duration(seconds: 2))),
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.red.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))]), child: Center(child: count > 1 ? Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)) : const Icon(Icons.sos, color: Colors.white, size: 22))),
                        ],
                      ),
                    ),
                  );
                }).toList());
              },
            ),
            StreamBuilder<List<FloodReport>>(
              stream: FirebaseService.streamFloodReports(),
              builder: (c, s) {
                final reps = s.data ?? [];
                return fm.MarkerLayer(markers: reps.map((r) => fm.Marker(point: LatLng(r.latitude, r.longitude), width: 48, height: 48, child: GestureDetector(onTap: () => _showFloodDetailPopup(r), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]), child: const Icon(Icons.camera_alt, color: Colors.white, size: 18))))).toList());
              },
            ),
            if (_currentRoute != null && _isNavigating) fm.PolylineLayer(polylines: [fm.Polyline(points: _currentRoute!.points, color: C.brand(context), strokeWidth: 5.5)]),
            fm.MarkerLayer(markers: [
              if (_currentPos != null) fm.Marker(point: _currentPos!, width: 55, height: 55, child: Transform.rotate(angle: _currentHeading * (pi/180), child: Icon(_isNavigating ? Icons.navigation : Icons.person_pin_circle, color: Colors.blue.shade700, size: 42))),
              ...widget.markers,
            ]),
          ],
        ),
        if (!_isNavigating && !widget.isSearchActive) AnimatedPositioned(duration: const Duration(milliseconds: 300), top: MediaQuery.of(context).padding.top + 75, right: 16, child: _modernWeatherChip().animate().fade(duration: const Duration(milliseconds: 400)).slideX(begin: 1.0, end: 0.0)),
        if (widget.topOverlay != null && !_isNavigating) Positioned(left: 16, right: 16, top: MediaQuery.of(context).padding.top + 12, child: widget.topOverlay!),
        if (_isNavigating) Positioned(top: MediaQuery.of(context).padding.top + 10, left: 12, right: 12, child: _navHeader()),
        Positioned(left: 16, bottom: widget.target != null || ORSNavigation.target.value != null ? 240 : 110, child: _modernLegend()),
        Positioned(right: 16, bottom: widget.target != null || ORSNavigation.target.value != null ? 230 : 110, child: Column(children: [
          ...widget.sideButtons,
          if (!widget.isRescuerMode) MapFab(icon: Icons.camera_alt, bg: C.brand(context), fg: Colors.white, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloodReportScreen()))).animate().scale(delay: const Duration(milliseconds: 200)),
          MapFab(icon: Icons.my_location, bg: Colors.white, fg: C.brand(context), onTap: _initMap).animate().scale(delay: const Duration(milliseconds: 300)),
        ])),
        if (_isNavigating) Positioned(left: 20, bottom: 120, child: _modernSpeedo()),
        if ((widget.target != null || ORSNavigation.target.value != null) && _currentRoute != null && !_isNavigating) Positioned(left: 16, right: 16, bottom: 24, child: _routeCard().animate().slideY(begin: 1.0, end: 0.0)),
        if (_loadingRoute) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  void _showSOSList(List<SOSRequest> requests) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Danh sách cứu hộ tại khu vực', style: T.title(ctx)), const SizedBox(height: 16), Flexible(child: ListView.separated(shrinkWrap: true, itemCount: requests.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (c, i) { final r = requests[i]; return ListTile(contentPadding: EdgeInsets.zero, title: Text(r.vehicleModel, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Biển số: ${r.vehiclePlate} · Mực nước: ${r.waterCm}cm'), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(ctx); _showSOSDetail(r); }); })), ])));
  }

  void _showSOSDetail(SOSRequest r) async {
    // VIỆC 1: KHÔNG vẽ route khi bấm marker nữa
    String distText = '...';
    String timeText = '...';
    if (_currentPos != null) {
       final d = Geolocator.distanceBetween(_currentPos!.latitude, _currentPos!.longitude, r.latitude, r.longitude) / 1000;
       distText = d < 1 ? '${(d*1000).round()} m' : '${d.toStringAsFixed(1)} km';
       timeText = '${(d * 2.5).round() + 2} phút';
    }
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Row(children: [StatusTag(r.status == 'pending' ? 'Yêu cầu mới' : (r.status == 'quoted' ? 'Đã gửi báo giá' : 'Đang xử lý'), bg: r.status == 'pending' ? Colors.red.shade50 : Colors.blue.shade50, fg: r.status == 'pending' ? Colors.red : Colors.blue), const Spacer(), Text(DateFormat('HH:mm').format(r.createdAt), style: T.caption(ctx))]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.vehicleModel, style: T.title(ctx).copyWith(fontSize: 22)), Text('Biển số: ${widget.isRescuerMode && r.status == 'pending' ? _maskPlate(r.vehiclePlate) : r.vehiclePlate}', style: T.body(ctx))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(distText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18)), Text('Dự kiến $timeText', style: T.caption(ctx))])]),
          const SizedBox(height: 12),
          FutureBuilder<String>(future: SearchService.reverseGeocode(r.latitude, r.longitude), builder: (c, snap) => Text(snap.data ?? 'Đang tải vị trí...', style: T.small(ctx).copyWith(color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)),
          const Divider(height: 40),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Mực nước', style: T.caption(ctx)), Text('${r.waterCm}cm', style: T.h2(ctx).copyWith(color: Colors.red))]), AppButton('Xem chi tiết xe', full: false, tone: Tone.ghost, onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(id: r.id))); })]),
          const SizedBox(height: 32),
          if (widget.isRescuerMode) ...[
            if (r.status == 'pending' || r.status == 'expanded')
              AppButton('BÁO GIÁ & NHẬN ĐƠN', height: 58, onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteInputScreen(req: r, distText: distText, timeText: timeText)));
              })
            else
              AppButton('DẪN ĐƯỜNG TRÊN BẢN ĐỒ', height: 58, icon: Icons.navigation, onTap: () {
                Navigator.pop(ctx);
                ORSNavigation.target.value = MapTarget(name: r.vehiclePlate, subtitle: r.vehicleModel, pos: LatLng(r.latitude, r.longitude));
                _startNavigation();
              }),
          ],
        ]),
      ),
    );
  }

  String _maskPlate(String p) => p.length > 3 ? '${p.substring(0,3)}-***.**' : p;

  void _showFloodDetailPopup(FloodReport r) {
    final expiryHours = 8 - DateTime.now().difference(r.reportedAt).inHours;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => Container(padding: const EdgeInsets.all(28), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [StatusTag(r.source == 'user' ? 'Người dùng báo' : 'Thiết bị cảm biến', bg: Colors.blue.shade50, fg: Colors.blue.shade700), const Spacer(), Text('Hết hạn sau ~$expiryHours giờ', style: T.caption(ctx).copyWith(color: Colors.orange.shade700, fontWeight: FontWeight.bold))]), const SizedBox(height: 20), if (r.photoThumb != null) ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(base64Decode(r.photoThumb!), width: double.infinity, height: 200, fit: BoxFit.cover)), const SizedBox(height: 20), FutureBuilder<String>(future: SearchService.reverseGeocode(r.latitude, r.longitude), builder: (c, snap) => Text(snap.data ?? 'Đang tải...', style: T.body(ctx).copyWith(fontWeight: FontWeight.bold))), const Divider(height: 40), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Mực nước', style: T.caption(ctx)), Text('${r.waterCm} cm', style: T.h2(ctx).copyWith(color: C.brand(ctx), fontSize: 32))]), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Báo cáo lúc', style: T.caption(ctx)), Text(DateFormat('HH:mm, dd/MM').format(r.reportedAt), style: T.body(ctx))])]), if (r.description != null && r.description!.isNotEmpty) ...[const SizedBox(height: 16), Text(r.description!, style: T.body(ctx).copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade700))], const SizedBox(height: 32), AppButton('Đóng', tone: Tone.ghost, height: 52, onTap: () => Navigator.pop(ctx))])));
  }

  Widget _modernWeatherChip() {
    if (_weather == null) return const SizedBox();
    final isDanger = _weather!.prob > 65;
    final color = isDanger ? Colors.orange.shade800 : Colors.blue.shade600;
    return GestureDetector(onTap: () => _showWeatherPanel(), child: ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.3))), child: Row(children: [Icon(isDanger ? Icons.thunderstorm : Icons.cloud, color: Colors.white, size: 20), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('${_weather!.temp.toStringAsFixed(1)}°C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.1)), Text('Mưa ${_weather!.prob.toStringAsFixed(0)}%', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11))])])))));
  }

  void _showWeatherPanel() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(padding: const EdgeInsets.all(28), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Thời tiết & Địa hình', style: T.title(ctx)), Text(_weather!.summary, style: T.caption(ctx).copyWith(color: Colors.blue.shade700, fontWeight: FontWeight.bold))])), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.wb_sunny_outlined, color: Colors.blue.shade700, size: 24))]), const SizedBox(height: 24), Row(children: [_statItem(Icons.thermostat, 'Nhiệt độ', '${_weather!.temp.toStringAsFixed(1)}°C'), _statItem(Icons.terrain, 'Độ cao', '${_weather!.elevation.toStringAsFixed(0)}m'), _statItem(Icons.water_drop, 'Xác suất', '${_weather!.prob.toStringAsFixed(0)}%')]), const SizedBox(height: 32), Text('Dự báo lượng mưa 6h tới (mm)', style: T.small(ctx).copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 20), _rainChart(), const SizedBox(height: 32), AppButton('Đóng', tone: Tone.ghost, height: 52, onTap: () => Navigator.pop(ctx))])));
  }

  Widget _statItem(IconData i, String k, String v) => Expanded(child: Column(children: [Icon(i, size: 24, color: Colors.blue), const SizedBox(height: 6), Text(k, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]));

  Widget _rainChart() {
    final maxRain = _weather!.hourly.isEmpty ? 1.0 : _weather!.hourly.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    final chartMax = maxRain < 5 ? 5.0 : maxRain;
    return SizedBox(height: 100, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: _weather!.hourly.map((h) { final barHeight = (h.amount / chartMax * 80).clamp(4.0, 80.0); final color = h.amount > 10 ? Colors.red : (h.amount > 2 ? Colors.orange : Colors.blue.shade300); return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${h.amount.toStringAsFixed(1)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Container(width: 20, height: barHeight, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))), const SizedBox(height: 4), Text('${h.hour}h', style: const TextStyle(fontSize: 10, color: Colors.grey))])); }).toList()));
  }

  Widget _modernLegend() {
    return GestureDetector(onTap: () => setState(() => _legendExpanded = !_legendExpanded), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(12), width: _legendExpanded ? 180 : 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.5))), child: _legendExpanded ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [_legItem(Colors.red, 'Rủi ro cao'), _legItem(Colors.orange, 'Rủi ro vừa'), _legItem(Colors.yellow, 'Cảnh báo trũng'), const Divider(height: 16), _legItem(Colors.red, 'Yêu cầu SOS', isMarker: true), _legItem(Colors.blue.shade700, 'Điểm ngập (ảnh)', isCamera: true)]) : Icon(Icons.layers_outlined, size: 24, color: Colors.grey.shade800)))));
  }

  Widget _legItem(Color c, String t, {bool isMarker = false, bool isCamera = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Container(width: 16, height: 16, decoration: BoxDecoration(color: isMarker ? Colors.red : (isCamera ? Colors.blue.shade700 : c.withValues(alpha: 0.5)), shape: (isMarker || isCamera) ? BoxShape.circle : BoxShape.rectangle, borderRadius: (isMarker || isCamera) ? null : BorderRadius.circular(4), border: Border.all(color: (isMarker || isCamera) ? Colors.white : c, width: (isMarker || isCamera) ? 2 : 1)), child: isCamera ? const Icon(Icons.camera_alt, size: 10, color: Colors.white) : null), const SizedBox(width: 10), Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]));

  Widget _navHeader() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [C.brand(context), C.brand(context).withValues(alpha: 0.8)]), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 6))]), child: Row(children: [const Icon(Icons.navigation, color: Colors.white, size: 32), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_nextInstruction.isEmpty ? "Dẫn đường an toàn..." : _nextInstruction, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)), if (_currentRoute != null) Text('${_currentRoute!.distanceText} · ${_currentRoute!.durationText}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13))])), IconButton(icon: const Icon(Icons.check_circle, color: Colors.white, size: 28), onPressed: _clearRoute)]));
  }

  Widget _modernSpeedo() {
    return Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: C.brand(context), width: 4), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_currentSpeed.round().toString(), style: T.h2(context).copyWith(fontSize: 28, height: 1)), const Text('km/h', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))]));
  }

  Widget _routeCard() {
    final MapTarget? target = widget.target ?? ORSNavigation.target.value;
    if (target == null) return const SizedBox();
    
    return AppCard(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [Expanded(child: Text(target.name, style: T.title(context).copyWith(fontSize: 20), maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(icon: const Icon(Icons.close, size: 24), onPressed: () { _clearRoute(); if (widget.onClearTarget != null) widget.onClearTarget!(); ORSNavigation.target.value = null; })]), const SizedBox(height: 8), Row(children: [Icon(Icons.access_time, size: 16, color: Colors.blue.shade600), const SizedBox(width: 6), if (_currentRoute != null) Text(_currentRoute!.durationText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(width: 20), Icon(Icons.route_outlined, size: 16, color: Colors.grey), const SizedBox(width: 6), if (_currentRoute != null) Text(_currentRoute!.distanceText, style: const TextStyle(fontSize: 15))]), const SizedBox(height: 24), AppButton('Bắt đầu di chuyển', height: 56, onTap: () { _startNavigation(); })]));
  }
}

class MapFab extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  const MapFab({super.key, required this.icon, required this.bg, required this.fg, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: GestureDetector(onTap: onTap, child: Container(width: 52, height: 52, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]), child: Icon(icon, color: fg, size: 24))));
  }
}
