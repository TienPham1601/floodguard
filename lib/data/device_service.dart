import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'vehicle_state.dart';
import 'firebase_service.dart';
import 'location_service.dart';
import 'app_settings.dart';

class DeviceService with WidgetsBindingObserver {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal() {
    _listenToAuth();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      debugPrint('BLE: App is closing (detached). Disconnecting...');
      disconnect();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disconnect();
  }

  void _listenToAuth() {
    FirebaseService.auth.authStateChanges().listen((user) {
      if (user != null) {
        initAutoConnect();
      } else {
        disconnect();
      }
    });
  }

  static const String serviceUuid = "4faf0001-1fb5-459e-8fcc-c5c9c331914b";
  static const String charDataUuid = "4faf0002-1fb5-459e-8fcc-c5c9c331914b";
  static const String charCmdUuid = "4faf0003-1fb5-459e-8fcc-c5c9c331914b";

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _dataChar;
  BluetoothCharacteristic? _cmdChar;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _connSubscription;

  bool _isAutoSosTriggered = false;
  String? _lastState;
  bool? _lastIntake;
  bool? _lastPower;
  Timer? _firstDataTimeout;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<void> initAutoConnect() async {
    final info = await FirebaseService.getSavedDeviceInfo();
    final savedId = info?['deviceId'];
    if (savedId != null && _connectedDevice == null) {
      debugPrint('BLE: Attempting auto-connect to $savedId');
      vehicle.isConnecting = true;
      vehicle.connectedDeviceName = info?['deviceName'] ?? 'FloodGuard';
      vehicle.refresh();
      _autoReconnect(savedId);
    }
  }

  void _autoReconnect(String deviceId) async {
    // 1. Kiểm tra systemDevices (kết nối treo ở tầng OS)
    try {
      List<BluetoothDevice> systemDevices = await FlutterBluePlus.systemDevices([Guid(serviceUuid)]);
      for (var d in systemDevices) {
        if (d.remoteId.str == deviceId) {
          debugPrint('BLE: Found saved device in systemDevices.');
          // Thử dùng lại kết nối này
          try {
            await connect(d);
            return;
          } catch (e) {
            debugPrint('BLE: Failed to reuse system device connection: $e. Cleaning up...');
            await d.disconnect();
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
    } catch (e) {
      debugPrint('BLE: systemDevices check error: $e');
    }

    // 2. Thử connect trực tiếp nếu đã biết ID
    BluetoothDevice device = BluetoothDevice.fromId(deviceId);
    try {
      await connect(device);
    } catch (e) {
      debugPrint('BLE: Direct connect failed, starting scan...');
      _scanAndConnect(deviceId);
    }
  }

  void _scanAndConnect(String deviceId) {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    StreamSubscription? sub;
    sub = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.remoteId.str == deviceId) {
          FlutterBluePlus.stopScan();
          sub?.cancel();
          debugPrint('BLE: Found saved device via scan: ${r.device.platformName}');
          connect(r.device);
          return;
        }
      }
    });

    // Timeout scan sau 10 giây nếu không thấy
    Future.delayed(const Duration(seconds: 10), () {
      if (!vehicle.isConnected && !vehicle.isConnecting) {
        debugPrint('BLE: Scan timeout, device not found.');
        vehicle.reconnectFailed = true;
        vehicle.isConnecting = false;
        vehicle.refresh();
      }
    });
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      vehicle.isConnecting = true;
      vehicle.refresh();
      
      debugPrint('BLE: connecting to ${device.platformName} (${device.remoteId})...');
      
      _connSubscription?.cancel();
      _firstDataTimeout?.cancel();

      // a. Kết nối (autoConnect: false để tránh conflict MTU)
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      
      // b. Request MTU trên Android
      await Future.delayed(const Duration(milliseconds: 500));
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512);
          debugPrint('BLE: MTU 512 requested');
        } catch (e) {
          debugPrint('BLE: MTU request error: $e');
        }
      }

      debugPrint('BLE: connected, discovering services...');
      
      // c. Discover Services
      List<BluetoothService> services = await device.discoverServices();
      debugPrint('BLE: services=${services.length}');
      
      BluetoothService? targetService;
      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == serviceUuid) {
          targetService = s;
          break;
        }
      }

      if (targetService == null) throw 'Không tìm thấy FloodGuard Service.';

      // d. Tìm Characteristics
      BluetoothCharacteristic? dataChar;
      BluetoothCharacteristic? cmdChar;
      for (var c in targetService.characteristics) {
        if (c.uuid.toString().toLowerCase() == charDataUuid) dataChar = c;
        if (c.uuid.toString().toLowerCase() == charCmdUuid) cmdChar = c;
      }

      if (dataChar == null || cmdChar == null) throw 'Thiết bị thiếu characteristic cần thiết.';

      _dataChar = dataChar;
      _cmdChar = cmdChar;

      // e. Bật Notify và ĐỢI gói dữ liệu đầu tiên (Timeout 10s)
      debugPrint('BLE: enabling notification and waiting for first packet...');
      await _startListening(dataChar);

      _firstDataTimeout = Timer(const Duration(seconds: 10), () {
        if (!vehicle.isFullyValidated) {
          debugPrint('BLE: Timeout waiting for first packet.');
          disconnect();
        }
      });

      _connSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('BLE: Disconnected state detected.');
          _onDisconnected();
        }
      });

      FirebaseService.saveDeviceId(device.remoteId.str, deviceName: device.platformName);

    } catch (e) {
      debugPrint('BLE: Connect error: $e');
      _onDisconnected();
      rethrow;
    }
  }

  void _onDisconnected() {
    debugPrint('BLE: cleaning up connection state');
    _firstDataTimeout?.cancel();
    _dataSubscription?.cancel();
    _connSubscription?.cancel();
    _dataChar = null;
    _cmdChar = null;
    _connectedDevice = null;
    vehicle.isConnected = false;
    vehicle.isConnecting = false;
    vehicle.isFullyValidated = false;
    vehicle.resetData();
    vehicle.refresh();
    _logEvent('disconnected', 'Mất kết nối Bluetooth với thiết bị.', severity: 'warning');
  }

  Future<void> _startListening(BluetoothCharacteristic c) async {
    await c.setNotifyValue(true);
    debugPrint('BLE: notify enabled');
    _dataSubscription = c.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        String jsonStr = utf8.decode(value);
        _parseData(jsonStr);
      }
    });
  }

  void _parseData(String jsonStr) {
    if (simulationMode.value) return;

    try {
      debugPrint('BLE: DATA RECEIVED: $jsonStr');
      Map<String, dynamic> data = json.decode(jsonStr);
      
      // Gói dữ liệu hợp lệ -> Xác thực thành công
      if (!vehicle.isFullyValidated) {
        _firstDataTimeout?.cancel();
        vehicle.isConnecting = false;
        vehicle.isConnected = true;
        vehicle.isFullyValidated = true;
        vehicle.connectedDeviceName = _connectedDevice?.platformName;
        _logEvent('connected', 'Thiết bị FloodGuard đã kết nối và gửi dữ liệu.');
        syncSettings();
      }

      vehicle.updateFromDevice(
        wet: data['wet'] ?? false,
        water: (data['water'] as num?)?.toDouble() ?? 0.0,
        state: data['state'] ?? 'idle',
        intake: data['intake'] ?? false,
        power: data['power'] ?? false,
        height: (data['height'] as num?)?.toDouble() ?? 40.0,
        warn: (data['warn'] as num?)?.toDouble() ?? 20.0,
        danger: (data['danger'] as num?)?.toDouble() ?? 35.0,
      );

      _handleNotifications(data['state'] ?? 'idle', (data['water'] as num?)?.toDouble() ?? 0.0);
      _handleStatusChanges(data['intake'] ?? false, data['power'] ?? false);
      _handleAutomation(data['state'] ?? 'idle', (data['water'] as num?)?.toDouble() ?? 0.0);

    } catch (e) {
      debugPrint('BLE: Parse error: $e');
    }
  }

  void _handleNotifications(String state, double water) {
    if (state != _lastState) {
      if (state == 'safe' && _lastState == 'idle') {
        _logEvent('water_detected', 'Cảm biến đã phát hiện nước tiếp xúc.', severity: 'warning');
      }
      if (state == 'warning') {
        _logEvent('warning', 'Mực nước vượt ngưỡng cảnh báo (${water.toStringAsFixed(1)}cm)', severity: 'warning');
        HapticFeedback.vibrate();
        _eventController.add({'type': 'warning', 'message': 'Xe đang vào vùng nước ngập - Cảnh báo'});
      }
      if (state == 'danger') {
        _logEvent('danger', 'Mực nước đạt ngưỡng NGUY HIỂM (${water.toStringAsFixed(1)}cm)', severity: 'danger');
        HapticFeedback.heavyImpact();
        _eventController.add({'type': 'danger', 'message': 'Mức nguy hiểm! Đã tự động đóng cổ hút'});
      }
      _lastState = state;
    }
  }

  void _handleStatusChanges(bool intake, bool power) {
    if (intake != _lastIntake) {
      if (_lastIntake != null) _logEvent('intake', intake ? 'Cổ hút đã ĐÓNG.' : 'Cổ hút đã MỞ.');
      _lastIntake = intake;
    }
    if (power != _lastPower) {
      if (_lastPower != null) _logEvent('power', power ? 'Nguồn điện đã NGẮT.' : 'Nguồn điện đã KHÔI PHỤC.');
      _lastPower = power;
    }
  }

  void _handleAutomation(String state, double water) {
    if (state == 'danger' && !_isAutoSosTriggered) {
      _triggerAutoSos(water.toInt());
      _isAutoSosTriggered = true;
    } else if (state == 'idle' || state == 'safe') {
      _isAutoSosTriggered = false;
    }
  }

  Future<void> sendCommand(String cmd) async {
    if (_cmdChar != null) {
      try {
        await _cmdChar!.write(utf8.encode(cmd));
        debugPrint('BLE: Sent command: $cmd');
      } catch (e) {
        debugPrint('BLE: Send error: $e');
      }
    }
  }

  void syncSettings() {
    sendCommand("SET_WARN:${vehicle.warnAt.toInt()}");
    sendCommand("SET_DANGER:${vehicle.dangerAt.toInt()}");
    sendCommand("SET_HEIGHT:${vehicle.sensorHeight.toInt()}");
  }

  void _logEvent(String type, String message, {String severity = 'info'}) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;
    final vSnap = await FirebaseService.streamCurrentVehicle().first;
    FirebaseService.addIncidentLog(user.uid, 'device', type, vSnap?.plate ?? '---', message, severity: severity);
  }

  void _triggerAutoSos(int waterCm) async {
    final user = FirebaseService.auth.currentUser;
    final vSnap = await FirebaseService.streamCurrentVehicle().first;
    if (user != null && vSnap != null) {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        FirebaseService.createSOS(vehicleId: vSnap.id, plate: vSnap.plate, model: vSnap.model, lat: pos.latitude, lng: pos.longitude, waterCm: waterCm);
        _logEvent('auto_sos', 'Hệ thống tự động gửi yêu cầu cứu hộ khẩn cấp.', severity: 'danger');
      }
    }
  }

  Future<void> disconnect() async {
    debugPrint('BLE: Manual disconnect requested.');
    _firstDataTimeout?.cancel();
    await _connectedDevice?.disconnect();
    _onDisconnected();
  }

  Future<void> forgetDevice() async {
    await disconnect();
    await FirebaseService.forgetDevice();
    vehicle.connectedDeviceName = null;
    vehicle.refresh();
  }
}

final deviceService = DeviceService();
