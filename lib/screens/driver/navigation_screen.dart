import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import '../../theme.dart';
import '../../ui.dart';
import '../../utils.dart';
import '../../data/directions.dart';

class NavigationScreen extends StatefulWidget {
  final Destination destination;
  final RouteResult route;
  final List<FloodPoint> hazards;
  final LatLng myPos;

  const NavigationScreen({
    super.key,
    required this.destination,
    required this.route,
    this.hazards = const [],
    required this.myPos,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final fm.MapController _mapController = fm.MapController();

  String get _arrivalTime {
    final t = DateTime.now().add(Duration(seconds: widget.route.durationSeconds));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  List<FloodPoint> get _nearby {
    final out = <FloodPoint>[];
    for (final f in floodPoints) {
      for (final p in widget.route.points) {
        final d = distanceKm(p.latitude, p.longitude, f.pos.latitude, f.pos.longitude);
        if (d <= 0.8) {
          out.add(f);
          break;
        }
      }
    }
    return out;
  }

  void _fit() {
    final all = [widget.myPos, widget.destination.pos, ...widget.route.points];
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

  @override
  Widget build(BuildContext context) {
    final hazardous = widget.hazards.isNotEmpty;
    final nearby = _nearby;

    return Scaffold(
      backgroundColor: C.bg(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Stack(children: [
            fm.FlutterMap(
              mapController: _mapController,
              options: fm.MapOptions(
                initialCenter: widget.myPos,
                initialZoom: 14,
                onMapReady: _fit,
              ),
              children: [
                fm.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.newcar',
                ),
                fm.PolylineLayer(
                  polylines: [
                    fm.Polyline(
                      points: widget.route.points,
                      color: hazardous ? C.danger(context) : C.brand(context),
                      strokeWidth: 7,
                    ),
                  ],
                ),
                fm.MarkerLayer(
                  markers: [
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
                    for (final f in nearby)
                      fm.Marker(
                        point: f.pos,
                        width: 30,
                        height: 30,
                        child: Icon(Icons.water_drop,
                            color: f.depthCm >= 40 ? Colors.red : Colors.orange,
                            size: 20),
                      ),
                  ],
                ),
              ],
            ),

            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.of(context).padding.top + 12,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(S.x4),
                  decoration: BoxDecoration(
                    color: hazardous ? C.danger(context) : C.brand(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (hazardous ? C.danger(context) : C.brand(context)).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.destination.name,
                            style: T.label(context, Colors.white).copyWith(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(widget.route.summary.isEmpty
                                ? widget.destination.address
                                : 'Qua ${widget.route.summary}',
                            style: T.body(context, Colors.white.withValues(alpha: 0.9))
                                .copyWith(fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                if (hazardous)
                  AlertBanner(
                    level: Level.danger,
                    text: 'Lộ trình này đi qua ${widget.hazards.length} điểm ngập vượt ngưỡng xe bạn.',
                  )
                else if (nearby.isNotEmpty)
                  AlertBanner(
                    text: 'Có ${nearby.length} điểm ngập gần tuyến đường. Lộ trình đã tránh.',
                  ),
              ]),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                decoration: BoxDecoration(
                  color: C.surface(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, -4)),
                  ],
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _stat(context, _arrivalTime, 'dự kiến đến'),
                    _stat(context, widget.route.durationText.replaceAll(' phút', ''), 'phút'),
                    _stat(context, widget.route.distanceText.replaceAll(' km', ''), 'km'),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: AppButton('Kết thúc', tone: Tone.ghost, height: 48,
                          onTap: () => Navigator.pop(context)),
                    ),
                    const SizedBox(width: S.x3),
                    Expanded(
                      flex: 2,
                      child: AppButton('Dẫn đường từng chặng', icon: Icons.navigation, height: 48,
                          onTap: () => openGoogleMapsDirections(
                              context, widget.myPos, widget.destination.pos)),
                    ),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _stat(BuildContext c, String value, String label) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: T.mono(c).copyWith(fontSize: 22)),
      Text(label, style: T.small(c)),
    ]);
  }
}
