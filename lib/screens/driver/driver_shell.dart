import 'package:flutter/material.dart';
// Removed unused: flutter_animate
import '../../ui.dart';
import '../../data/firebase_service.dart';
import 'car_screen.dart';
import 'map_screen.dart';
import 'sos_screen.dart';
import 'insurance_report_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final titles = ['Xe của tôi', 'Bản đồ', 'SOS', 'Bảo hiểm', 'Cá nhân'];
    final bodies = [
      const CarScreen(),
      const MapScreen(),
      const SosScreen(),
      const InsuranceReportScreen(),
      const ProfileScreen(),
    ];

    final isMap = _tab == 1;

    return StreamBuilder<VehicleData?>(
      stream: FirebaseService.streamCurrentVehicle(),
      builder: (context, snapshot) {
        String barTitle = titles[_tab];
        
        if (_tab == 0) {
          final vehicle = snapshot.data;
          if (vehicle != null) {
            barTitle = vehicle.model;
          } else if (snapshot.connectionState != ConnectionState.waiting) {
            barTitle = 'Chưa có xe';
          }
        }

        return Screen(
          bar: isMap
              ? null
              : topBar(context, barTitle,
                  right: [
                    if (_tab == 0)
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                  ]),
          nav: AppBottomNav(index: _tab, onChanged: (i) => setState(() => _tab = i)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: bodies[_tab],
          ),
        );
      },
    );
  }
}
