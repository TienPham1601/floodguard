import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme.dart';
import '../../ui.dart';
import 'wifi_device_screen.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  List<ScanResult> _devices = [];
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
      final status = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (status.values.every((s) => s.isGranted)) {
        setState(() {
          _devices.clear();
          _isScanning = true;
        });

        _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
          if (mounted) {
            setState(() {
              _devices = results.where((r) => r.device.platformName.isNotEmpty).toList();
            });
          }
        });

        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        if (mounted) setState(() => _isScanning = false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cần cấp quyền Bluetooth và Vị trí để tìm thiết bị.'))
          );
        }
      }
    } catch (e) {
      debugPrint('Scan error: $e');
    }
  }

  void _goToWifi() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WifiDeviceScreen()),
    );
  }

  Future<void> _connectToEsp32(BluetoothDevice device) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đang kết nối tới ${device.platformName}...'))
      );
      // TODO: Sẽ hoàn thiện khi có thiết bị ESP32 thật
      // await device.connect();
      
      if (mounted) _goToWifi();
    } catch (e) {
      debugPrint('Connection error: $e');
      if (mounted) _goToWifi(); // Vẫn đi tiếp luồng dù lỗi kết nối demo
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

            if (_devices.isEmpty && !_isScanning)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('Chưa tìm thấy thiết bị nào quanh đây.', textAlign: TextAlign.center),
              ))
            else
              for (var d in _devices)
                _deviceItem(context, d),

            const SizedBox(height: S.x5),
            AppButton('Bỏ qua bước này', tone: Tone.ghost, onTap: _goToWifi),
          ],
        ),
      ),
    );
  }

  Widget _deviceItem(BuildContext c, ScanResult result) {
    return ListTile(
      onTap: () => _connectToEsp32(result.device),
      leading: const Icon(Icons.bluetooth),
      title: Text(result.device.platformName),
      subtitle: Text(result.device.remoteId.str),
      trailing: const Icon(Icons.chevron_right),
      shape: Border(bottom: BorderSide(color: C.line(c))),
    );
  }
}
