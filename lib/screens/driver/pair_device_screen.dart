import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/device_service.dart';
import 'wifi_device_screen.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  List<ScanResult> _devices = [];
  List<BluetoothDevice> _systemDevices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      List<Permission> permissions = [];
      
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        debugPrint('BLE_PERM: Android SDK Int = $sdkInt');
        
        if (sdkInt >= 31) { // Android 12+
          permissions = [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ];
        } else { // Android 11-
          permissions = [
            Permission.location,
          ];
        }
      } else {
        permissions = [Permission.bluetooth];
      }

      Map<Permission, PermissionStatus> statuses = await permissions.request();
      bool allGranted = true;
      bool permanentlyDenied = false;

      statuses.forEach((permission, status) {
        debugPrint('BLE_PERM: $permission = $status');
        if (!status.isGranted) allGranted = false;
        if (status.isPermanentlyDenied) permanentlyDenied = true;
      });

      if (allGranted) {
        setState(() {
          _devices.clear();
          _systemDevices.clear();
          _isScanning = true;
        });

        // 1. Kiểm tra các thiết bị hệ thống đang giữ kết nối (treo)
        try {
          _systemDevices = await FlutterBluePlus.systemDevices([Guid(DeviceService.serviceUuid)]);
          _systemDevices = _systemDevices.where((d) => d.platformName.toLowerCase().contains('floodguard')).toList();
          for (var d in _systemDevices) {
            debugPrint('BLE: System device found: ${d.platformName} [${d.remoteId}]');
          }
        } catch (e) {
          debugPrint('BLE: systemDevices check error: $e');
        }

        _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
          if (mounted) {
            setState(() {
              _devices = results.where((r) {
                final name = r.device.platformName.toLowerCase();
                final advName = r.advertisementData.advName.toLowerCase();
                final isFloodGuard = name.startsWith('floodguard') || advName.startsWith('floodguard');
                
                // Tránh hiện trùng thiết bị đã có trong mục "Đã ghép nối"
                final isAlreadyInSystem = _systemDevices.any((sd) => sd.remoteId == r.device.remoteId);
                
                return isFloodGuard && !isAlreadyInSystem;
              }).toList();
            });
          }
        });

        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        if (mounted) {
          setState(() => _isScanning = false);
          if (_devices.isEmpty && _systemDevices.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không tìm thấy thiết bị FloodGuard. Kiểm tra thiết bị đã bật nguồn chưa.'))
            );
          }
        }
      } else {
        if (mounted) {
          if (permanentlyDenied) {
             _showSettingsDialog();
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Cần cấp quyền để tìm thiết bị.'))
             );
          }
        }
      }
    } catch (e) {
      debugPrint('Scan error: $e');
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Thiếu quyền truy cập'),
        content: const Text('Bạn đã từ chối quyền truy cập Bluetooth/Vị trí. Vui lòng mở Cài đặt ứng dụng để cấp quyền thủ công.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng')),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              openAppSettings();
            }, 
            child: const Text('Mở Cài đặt', style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _goToWifi() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WifiDeviceScreen()),
    );
  }

  Future<void> _connectToEsp32(BluetoothDevice device) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      
      await deviceService.connect(device);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã kết nối tới ${device.platformName}'))
        );
        _goToWifi();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Ngăn back về màn rỗng
      child: Screen(
        bar: topBar(context, 'Bước 1: Ghép nối Bluetooth'),
        child: ListView(
          padding: const EdgeInsets.all(S.x4),
          children: [
            const AlertBanner(
              level: Level.safe,
              icon: Icons.bluetooth,
              text: 'Bật Bluetooth trên điện thoại và đảm bảo thiết bị FloodGuard đã được cấp nguồn.',
            ),
            const SizedBox(height: S.x4),

            _isScanning 
              ? const Center(child: CircularProgressIndicator())
              : AppButton('Tìm thiết bị', icon: Icons.search, onTap: _startScan),
            const SizedBox(height: S.x4),

            if (_systemDevices.isEmpty && _devices.isEmpty && !_isScanning)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Text('Không tìm thấy thiết bị FloodGuard.\nKiểm tra thiết bị đã bật nguồn chưa.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    AppButton('Quét lại', icon: Icons.refresh, full: false, onTap: _startScan),
                  ],
                ),
              ))
            else ...[
              if (_systemDevices.isNotEmpty) ...[
                Text('THIẾT BỊ ĐÃ GHÉP NỐI', style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                for (var d in _systemDevices) _systemDeviceItem(context, d),
                const SizedBox(height: 24),
              ],
              
              if (_devices.isNotEmpty) ...[
                Text('THIẾT BỊ TÌM THẤY', style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                for (var d in _devices) _deviceItem(context, d),
              ],
            ],

            const SizedBox(height: S.x5),
            AppButton('Bỏ qua bước này', tone: Tone.ghost, onTap: _goToWifi),
          ],
        ),
      ),
    );
  }

  Widget _systemDeviceItem(BuildContext c, BluetoothDevice device) {
    return ListTile(
      onTap: () => _connectToEsp32(device),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
        child: Icon(Icons.history, color: C.muted(c), size: 20),
      ),
      title: Text(device.platformName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Đã ghép nối trước đó · ${device.remoteId.str}', style: T.caption(c)),
      trailing: const Icon(Icons.chevron_right),
      shape: Border(bottom: BorderSide(color: C.line(c))),
    );
  }

  Widget _deviceItem(BuildContext c, ScanResult result) {
    final name = result.device.platformName.isNotEmpty 
        ? result.device.platformName 
        : (result.advertisementData.advName.isNotEmpty ? result.advertisementData.advName : "Unknown");

    return ListTile(
      onTap: () => _connectToEsp32(result.device),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: C.brandBg(c), shape: BoxShape.circle),
        child: Icon(Icons.bluetooth, color: C.brand(c), size: 20),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MAC: ${result.device.remoteId.str}', style: T.caption(c)),
          Text('Sóng (RSSI): ${result.rssi} dBm', style: T.caption(c).copyWith(color: result.rssi > -70 ? Colors.green : Colors.orange)),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      isThreeLine: true,
      shape: Border(bottom: BorderSide(color: C.line(c))),
    );
  }
}
