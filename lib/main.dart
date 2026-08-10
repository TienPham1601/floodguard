import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'data/app_settings.dart';
import 'data/firebase_service.dart';
import 'screens/driver/pair_device_screen.dart';
import 'screens/driver/add_vehicle_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/driver/driver_shell.dart';
import 'screens/rescue/rescue_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Tự động dọn đơn treo lúc mở app
  FirebaseService.cleanupExpiredSOS();

  runApp(const FloodGuardApp());
}

class FloodGuardApp extends StatelessWidget {
  const FloodGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'FloodGuard',
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          darkTheme: appTheme(Brightness.dark),
          themeMode: mode,
          builder: (context, child) {
             return ScrollConfiguration(
               behavior: const ScrollBehavior().copyWith(physics: const BouncingScrollPhysics()),
               child: child!,
             );
          },
          home: StreamBuilder<User?>(
            stream: FirebaseService.authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const SplashScreen();
              
              final user = snapshot.data;
              if (user == null) {
                return const LoginScreen();
              }

              return FutureBuilder<Map<String, dynamic>?>(
                future: FirebaseService.getUserProfile(),
                builder: (context, profSnap) {
                  if (profSnap.connectionState == ConnectionState.waiting) return const SplashScreen();
                  
                  final userData = profSnap.data;
                  if (userData == null) return const SplashScreen(); 
                  
                  final role = userData['role'] ?? 'driver';
                  final bool setupDone = userData['deviceSetupDone'] ?? false;

                  if (role == 'rescuer') return const RescueShell();

                  // Nhánh Driver
                  return StreamBuilder<VehicleData?>(
                    stream: FirebaseService.streamCurrentVehicle(),
                    builder: (context, vehicleSnap) {
                      if (vehicleSnap.connectionState == ConnectionState.waiting) return const SplashScreen();
                      
                      final vehicle = vehicleSnap.data;
                      if (vehicle == null) return const AddVehicleScreen(isFirstTime: true);
                      
                      // Kích hoạt lắng nghe SOS cho xe này
                      FirebaseService.listenToVehicleSOS(vehicle.id);
                      
                      if (!setupDone) return const PairDeviceScreen();

                      return const DriverShell();
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
