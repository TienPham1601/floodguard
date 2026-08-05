import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../theme.dart';
// unused imports removed
import '../../widgets/app_map.dart';
import 'unit_profile_screen.dart';
import 'rescue_list_tab.dart';

class RescueShell extends StatefulWidget {
  const RescueShell({super.key});
  @override
  State<RescueShell> createState() => _RescueShellState();
}

class _RescueShellState extends State<RescueShell> {
  int _idx = 0;
  LatLng _myPos = const LatLng(21.0285, 105.8542);

  @override
  void initState() {
    super.initState();
    Geolocator.getCurrentPosition().then((p) {
      if (mounted) setState(() => _myPos = LatLng(p.latitude, p.longitude));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: [
        AppMap(center: _myPos, markers: const [], isRescuerMode: true),
        RescueListTab(myPos: _myPos),
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
