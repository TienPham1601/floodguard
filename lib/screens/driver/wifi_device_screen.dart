import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import 'driver_shell.dart';
import '../rescue/rescue_shell.dart';

class WifiDeviceScreen extends StatefulWidget {
  const WifiDeviceScreen({super.key});

  @override
  State<WifiDeviceScreen> createState() => _WifiDeviceScreenState();
}

class _WifiDeviceScreenState extends State<WifiDeviceScreen> {
  List<WiFiAccessPoint> _networks = [];
  bool _isScanning = false;

  Future<void> _startScan() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        setState(() => _isScanning = true);
        
        final canScan = await WiFiScan.instance.canStartScan();
        if (canScan == CanStartScan.yes) {
          await WiFiScan.instance.startScan();
          final results = await WiFiScan.instance.getScannedResults();
          if (mounted) {
            setState(() {
              _networks = results;
              _isScanning = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => _isScanning = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể quét WiFi: $canScan')));
          }
        }
      }
    } catch (e) {
      debugPrint('Wifi scan error: $e');
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _setupWifi(WiFiAccessPoint ap) {
    final passCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kết nối ${ap.ssid}'),
        content: TextField(
          controller: passCtl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Mật khẩu WiFi'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finish();
            },
            child: const Text('Kết nối'),
          ),
        ],
      ),
    );
  }

  void _finish() async {
    try {
      await FirebaseService.completeSetup();
      if (!mounted) return;
      
      final profile = await FirebaseService.getUserProfile();
      if (!mounted) return;
      final role = profile?['role'] ?? 'driver';

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'rescuer' ? const RescueShell() : const DriverShell()
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Finish error: $e');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DriverShell()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Screen(
        bar: topBar(context, 'Bước 2: Cài đặt WiFi'),
        child: ListView(
          padding: const EdgeInsets.all(S.x4),
          children: [
            const AlertBanner(
              level: Level.safe,
              icon: Icons.wifi,
              text: 'Thiết bị cần kết nối WiFi để gửi cảnh báo từ xa. Hãy chọn mạng WiFi tại nơi bạn đỗ xe.',
            ),
            const SizedBox(height: S.x4),

            _isScanning 
              ? const Center(child: CircularProgressIndicator())
              : AppButton('Quét mạng WiFi', icon: Icons.refresh, onTap: _startScan),
            const SizedBox(height: S.x4),

            if (_networks.isEmpty && !_isScanning)
              const Center(child: Text('Chưa tìm thấy mạng nào.'))
            else
              for (var ap in _networks)
                _wifiItem(context, ap),

            const SizedBox(height: S.x5),
            AppButton('Hoàn tất và vào ứng dụng', onTap: _finish),
            const SizedBox(height: S.x3),
            AppButton('Bỏ qua bước này', tone: Tone.ghost, onTap: _finish),
          ],
        ),
      ),
    );
  }

  Widget _wifiItem(BuildContext c, WiFiAccessPoint ap) {
    return ListTile(
      onTap: () => _setupWifi(ap),
      leading: const Icon(Icons.wifi),
      title: Text(ap.ssid.isEmpty ? '[Mạng ẩn]' : ap.ssid),
      subtitle: Text('Tín hiệu: ${ap.level} dBm'),
      trailing: const Icon(Icons.lock_outline, size: 16),
      shape: Border(bottom: BorderSide(color: C.line(c))),
    );
  }
}
