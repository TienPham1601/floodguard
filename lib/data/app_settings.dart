import 'package:flutter/material.dart';

/// Cài đặt toàn app.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Bật thì màn Xe của tôi hiện thanh điều khiển mô phỏng.
final simulationMode = ValueNotifier<bool>(false);

/// Giai đoạn của app: khởi động → đăng nhập → vào app.
enum AppStage { splash, login, app }
final appStage = ValueNotifier<AppStage>(AppStage.splash);

/// Tài khoản vừa đăng ký, dùng để điền sẵn ở màn đăng nhập.
final registeredPhone = ValueNotifier<String>('');
final registeredName = ValueNotifier<String>('');
