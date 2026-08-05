import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import '../../theme.dart';
import '../../ui.dart';
import '../../utils.dart';
import '../../data/directions.dart';
import '../../data/vehicle_state.dart';
import 'navigation_screen.dart';

class RouteCompareScreen extends StatefulWidget {
  final Destination destination;
  final LatLng myPos;
  const RouteCompareScreen({super.key, required this.destination, required this.myPos});

  @override
  State<RouteCompareScreen> createState() => _RouteCompareScreenState();
}

class _Option {
  final RouteResult route;
  final List<FloodPoint> hazards;
  const _Option(this.route, this.hazards);

  bool get safe => hazards.isEmpty;
}

class _RouteCompareScreenState extends State<RouteCompareScreen> {
  final fm.MapController _mapController = fm.MapController();
  List<_Option> _options = [];
  int _selected = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routes = await RoutingService.fetchRoutes(widget.myPos, widget.destination.pos);
    if (!mounted) return;

    final opts = routes.map((r) => _Option(r, _hazardsOn(r))).toList();
    opts.sort((a, b) {
      if (a.safe != b.safe) return a.safe ? -1 : 1;
      return a.route.durationSeconds.compareTo(b.route.durationSeconds);
    });

    setState(() {
      _options = opts;
      _loading = false;
    });
    _fit();
  }

  List<FloodPoint> _hazardsOn(RouteResult route) {
    final out = <FloodPoint>[];
    // Giả sử floodPoints vẫn từ data/places.dart cho demo logic, 
    // hoặc có thể stream từ Firestore nếu cần.
    for (final f in floodPoints) {
      if (f.depthCm < vehicle.dangerAt) continue;
      for (final p in route.points) {
        final d = distanceKm(p.latitude, p.longitude, f.pos.latitude, f.pos.longitude);
        if (d <= 0.15) {
          out.add(f);
          break;
        }
      }
    }
    return out;
  }

  void _fit() {
    if (_options.isEmpty) return;
    final all = [widget.myPos, widget.destination.pos, ..._options[_selected].route.points];
    double minLat = all.first.latitude, maxLat = all.first.latitude;
    double minLng = all.first.longitude, maxLng = all.first.longitude;
    for (final p in all) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    _mapController.fitCamera(
      fm.CameraFit.bounds(
        bounds: fm.LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(70),
      ),
    );
  }

  List<fm.Polyline> _polylines(BuildContext c) {
    final out = <fm.Polyline>[];
    for (int i = 0; i < _options.length; i++) {
      final o = _options[i];
      final chosen = i == _selected;
      out.add(fm.Polyline(
        points: o.route.points,
        color: chosen
            ? (o.safe ? C.safe(c) : C.danger(c))
            : C.muted(c).withValues(alpha: 0.5),
        strokeWidth: chosen ? 7 : 4,
      ));
    }
    return out;
  }

  List<fm.Marker> _markers() {
    final out = <fm.Marker>[
      fm.Marker(
        point: widget.myPos,
        width: 30,
        height: 30,
        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30),
      ),
      fm.Marker(
        point: widget.destination.pos,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.deepPurple, size: 40),
      ),
    ];
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Chọn lộ trình',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: Column(children: [
        SizedBox(
          height: 260,
          child: fm.FlutterMap(
            mapController: _mapController,
            options: fm.MapOptions(
              initialCenter: widget.myPos,
              initialZoom: 13,
            ),
            children: [
              fm.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.newcar',
              ),
              fm.PolylineLayer(polylines: _polylines(context)),
              fm.MarkerLayer(markers: _markers()),
            ],
          ),
        ),
        Expanded(child: _body(context)),
      ]),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: C.brand(context)),
          const SizedBox(height: 14),
          Text('Đang tìm lộ trình…', style: T.small(context)),
        ]),
      );
    }

    if (_options.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          const AlertBanner(
            text: 'Chưa lấy được lộ trình. Kiểm tra kết nối mạng rồi thử lại.',
          ),
          const SizedBox(height: S.x4),
          AppButton('Mở chỉ đường trong Google Maps', icon: Icons.navigation,
              onTap: () => openGoogleMapsDirections(context, widget.myPos, widget.destination.pos)),
        ],
      );
    }

    final chosen = _options[_selected];
    return ListView(
      padding: const EdgeInsets.all(S.x4),
      children: [
        for (int i = 0; i < _options.length; i++) ...[
          _routeCard(context, _options[i], i),
          const SizedBox(height: S.x3),
        ],
        if (_options.length > 1 && _options.first.safe && !_options.last.safe)
          const AlertBanner(
            level: Level.safe,
            icon: Icons.check_circle_outline,
            text: 'Đường an toàn tránh được mọi điểm ngập vượt ngưỡng của xe bạn.',
          ),
        const SizedBox(height: S.x4),
        AppButton('Bắt đầu dẫn đường', icon: Icons.navigation, onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => NavigationScreen(
              destination: widget.destination,
              route: chosen.route,
              hazards: chosen.hazards,
              myPos: widget.myPos,
            ),
          ));
        }),
      ],
    );
  }

  Widget _routeCard(BuildContext c, _Option o, int index) {
    final chosen = index == _selected;
    final color = o.safe ? C.safe(c) : C.danger(c);
    return InkWell(
      onTap: () {
        setState(() => _selected = index);
        _fit();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(S.x4),
        decoration: BoxDecoration(
          color: C.surface(c),
          border: Border.all(color: chosen ? color : C.line(c), width: chosen ? 1.5 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StatusTag(
              o.safe
                  ? (index == 0 ? 'Khuyên dùng · An toàn' : 'An toàn')
                  : '${o.hazards.length} điểm ngập',
              fg: color,
              bg: o.safe ? C.safeBg(c) : C.dangerBg(c),
            ),
            const Spacer(),
            Text(o.route.durationText,
                style: T.mono(c, chosen ? color : C.muted(c)).copyWith(fontSize: 17)),
          ]),
          const SizedBox(height: 8),
          Text(o.route.summary.isEmpty ? 'Lộ trình ${index + 1}' : 'Qua ${o.route.summary}',
              style: T.body(c).copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(
            o.safe
                ? '${o.route.distanceText} · không có điểm ngập'
                : '${o.route.distanceText} · sâu nhất ${o.hazards.map((h) => h.depthCm).reduce((a, b) => a > b ? a : b)}cm, vượt ngưỡng xe bạn',
            style: T.small(c),
          ),
        ]),
      ),
    );
  }
}
