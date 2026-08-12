import 'package:flutter/material.dart';

/// Trạng thái sống của xe. Ở bản này dùng dữ liệu mô phỏng trong bộ nhớ.
/// Khi có thiết bị thật, chỉ cần thay nguồn cập nhật waterCm/tempC... ở đây.
class VehicleState extends ChangeNotifier {
  String plate = '';
  String model = '';
  String id = '';

  // Trạng thái thiết bị
  bool isConnected = false;
  bool isConnecting = false;
  bool reconnectFailed = false;
  bool isFullyValidated = false; // Chỉ true khi đã nhận được gói JSON đầu tiên
  String? connectedDeviceName;
  int batteryLevel = 0;
  String deviceVersion = 'v1.2.0';

  bool isWet = false;
  String deviceState = 'idle'; // idle, safe, warning, danger
  double sensorHeight = 40;

  double waterCm = 0;
  double warnAt = 20;
  double dangerAt = 35;
  
  double tempC = 31;
  double humidity = 62;
  double pm25 = 31;
  bool personInside = false;

  bool intakeClosed = false;
  bool powerCut = false;
  bool autoProtect = true;

  Duration parkedFor = const Duration(hours: 2);

  void setConnection(bool connected, {int? battery}) {
    isConnected = connected;
    if (battery != null) batteryLevel = battery;
    notifyListeners();
  }

  void setWater(double v) {
    waterCm = v.clamp(0, 60);
    if (autoProtect && waterCm >= dangerAt) {
      intakeClosed = true;
      powerCut = true;
    } else if (waterCm < warnAt) {
      intakeClosed = false;
      powerCut = false;
    }
    notifyListeners();
  }

  void updateFromDevice({
    required bool wet,
    required double water,
    required String state,
    required bool intake,
    required bool power,
    required double height,
    required double warn,
    required double danger,
  }) {
    isWet = wet;
    deviceState = state;
    sensorHeight = height;
    waterCm = water;
    intakeClosed = intake;
    powerCut = power;
    warnAt = warn;
    dangerAt = danger;
    notifyListeners();
  }

  void toggleAuto() {
    autoProtect = !autoProtect;
    notifyListeners();
  }

  void saveThresholds(double newWarn, double newDanger, {double? newHeight}) {
    warnAt = newWarn;
    dangerAt = newDanger;
    if (newHeight != null) sensorHeight = newHeight;
    notifyListeners();
  }

  void setCabin({double? tempC, double? humidity, double? pm25, bool? personInside}) {
    if (tempC != null) this.tempC = tempC;
    if (humidity != null) this.humidity = humidity;
    if (pm25 != null) this.pm25 = pm25;
    if (personInside != null) this.personInside = personInside;
    notifyListeners();
  }

  void resetData() {
    waterCm = 0;
    isWet = false;
    deviceState = 'idle';
    intakeClosed = false;
    powerCut = false;
    notifyListeners();
  }

  void resetToSafe() {
    waterCm = 8;
    tempC = 31;
    humidity = 62;
    pm25 = 31;
    personInside = false;
    isWet = true;
    deviceState = 'safe';
    intakeClosed = false;
    powerCut = false;
    notifyListeners();
  }

  void toggleIntake() {
    intakeClosed = !intakeClosed;
    notifyListeners();
  }

  void togglePower() {
    powerCut = !powerCut;
    notifyListeners();
  }

  /// Thông báo cho các listener cập nhật UI
  void refresh() {
    notifyListeners();
  }
}

final vehicle = VehicleState();
