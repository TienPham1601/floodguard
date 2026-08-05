import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme.dart';
// Removed unused: import '../../ui.dart';
import '../../data/firebase_service.dart';
import '../../widgets/app_map.dart';
import 'request_detail_screen.dart';

class RescueMapScreen extends StatefulWidget {
  const RescueMapScreen({super.key});
  @override
  State<RescueMapScreen> createState() => _RescueMapScreenState();
}

class _RescueMapScreenState extends State<RescueMapScreen> {
  final _mapKey = GlobalKey<AppMapState>();
  MapTarget? _target;
  LatLng _myPos = const LatLng(21.0285, 105.8542);
  double _radius = 15.0;

  @override
  void initState() {
    super.initState();
    _initRescueData();
  }

  Future<void> _initRescueData() async {
    final pos = await Geolocator.getCurrentPosition();
    final prof = await FirebaseService.getUserProfile();
    if (mounted) {
      setState(() {
        _myPos = LatLng(pos.latitude, pos.longitude);
        _radius = (prof?['serviceRadius'] as num?)?.toDouble() ?? 15.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SOSRequest>>(
      stream: FirebaseService.streamActiveSOS(isRescuer: true),
      builder: (context, snapshot) {
        final allRequests = snapshot.data ?? [];
        
        // LỌC BÁN KÍNH
        final requests = allRequests.where((r) {
          final d = Geolocator.distanceBetween(_myPos.latitude, _myPos.longitude, r.latitude, r.longitude) / 1000;
          return d <= _radius;
        }).toList();

        debugPrint('RESCUE_MAP: Snapshot received. Total=${allRequests.length}, InRadius=${requests.length}');

        return AppMap(
          key: _mapKey,
          center: _myPos,
          markers: requests.map((r) => fm.Marker(
            point: LatLng(r.latitude, r.longitude),
            width: 50, height: 50,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(id: r.id))),
              child: const Icon(Icons.sos, color: Colors.red, size: 36),
            ),
          )).toList(),
          target: _target,
          onClearTarget: () => setState(() => _target = null),
          sideButtons: [
            MapFab(
              icon: Icons.my_location,
              bg: C.surface(context),
              fg: C.brand(context),
              onTap: () => _mapKey.currentState?.moveTo(_myPos),
            ),
          ],
        );
      }
    );
  }
}
