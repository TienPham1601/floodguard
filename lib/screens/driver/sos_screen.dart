import 'dart:async';
import 'package:flutter/material.dart';
// Removed unused: dart:developer
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'insurance_report_screen.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../utils.dart';
import '../../data/location_service.dart';
import '../../data/places.dart';
import '../../data/firebase_service.dart';

// MỐC THỜI GIAN TEST
const int SEARCH_LIMIT_SECONDS = 30;
const int TIMEOUT_SECONDS = 45;

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  static const _holdDuration = Duration(seconds: 2);
  Timer? _timer;
  double _progress = 0;
  LatLng? _currentPos;
  String _address = 'Đang định vị...';
  VehicleData? _currentVehicle;

  late Stream<VehicleData?> _vehicleStream;
  late Stream<SOSRequest?> _sosStream;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _vehicleStream = FirebaseService.streamCurrentVehicle();
    _sosStream = FirebaseService.currentVehicleSosStream;
    FirebaseService.cleanupExpiredSOS();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) {
      final addr = await SearchService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) setState(() { _currentPos = pos; _address = addr; });
    }
  }

  void _startHold() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) return t.cancel();
      setState(() => _progress += 50 / _holdDuration.inMilliseconds);
      if (_progress >= 1) { t.cancel(); _send(); }
    });
  }

  void _cancelHold() {
    _timer?.cancel();
    if (mounted) setState(() => _progress = 0);
  }

  void _send() async {
    if (_currentVehicle == null || _currentPos == null) {
      _cancelHold();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn xe và đợi GPS.')));
      return;
    }
    HapticFeedback.heavyImpact();
    try {
      await FirebaseService.createSOS(
        vehicleId: _currentVehicle!.id,
        plate: _currentVehicle!.plate,
        model: _currentVehicle!.model,
        lat: _currentPos!.latitude,
        lng: _currentPos!.longitude,
        waterCm: _currentVehicle!.waterCm.toInt(),
      );
      if (mounted) setState(() => _progress = 1);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VehicleData?>(
      stream: _vehicleStream,
      builder: (context, vSnap) {
        _currentVehicle = vSnap.data;
        return StreamBuilder<SOSRequest?>(
          stream: _sosStream,
          initialData: FirebaseService.cachedSOS,
          builder: (context, sosSnap) {
            final activeSOS = sosSnap.data;
            final bool isReallyActive = activeSOS != null && 
                ['pending', 'accepted', 'processing', 'expanded'].contains(activeSOS.status);

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: !isReallyActive 
                ? _buildIdleUI(context) 
                : _buildActiveUI(context, activeSOS),
            );
          },
        );
      },
    );
  }

  Widget _buildIdleUI(BuildContext context) {
    return ListView(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 20),
        Text('Cứu hộ khẩn cấp', style: T.h2(context).copyWith(fontSize: 28)),
        const SizedBox(height: 8),
        Text('Nhấn và giữ nút bên dưới để gửi yêu cầu cứu hộ ngay lập tức.', style: T.body(context, C.muted(context))),
        const SizedBox(height: 60),
        Center(child: _sosButtonMain()),
        const SizedBox(height: 80),
        _infoCard(context),
      ],
    );
  }

  Widget _sosButtonMain() {
    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 210, height: 210,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 6,
              color: Colors.red.shade400,
              backgroundColor: Colors.grey.shade100,
            ),
          ),
          Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade800],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 10, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sos, color: Colors.white, size: 56),
                const SizedBox(height: 4),
                Text('GIỮ 2 GIÂY', style: T.label(context, Colors.white).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w900)),
              ],
            ),
          ).animate(target: _progress > 0 ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(0.95, 0.95), duration: const Duration(milliseconds: 200)),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.directions_car, size: 20, color: C.brand(context)),
          const SizedBox(width: 10),
          Text('Phương tiện đang chọn', style: T.small(context).copyWith(fontWeight: FontWeight.bold)),
        ]),
        const Divider(height: 24),
        _kv('Xe', _currentVehicle?.model ?? 'Chưa có xe'),
        _kv('Biển số', _currentVehicle?.plate ?? '---'),
        _kv('Vị trí', _address),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 80, child: Text(k, style: T.caption(context))), Expanded(child: Text(v, style: T.small(context).copyWith(fontWeight: FontWeight.w600)))]));

  Widget _buildActiveUI(BuildContext context, SOSRequest req) {
    if (req.status == 'accepted' || req.status == 'processing') return _buildAcceptedUI(req);
    if (req.status == 'timeout') return _buildTimeoutUI(req);
    return _WaitingView(req: req);
  }

  Widget _buildAcceptedUI(SOSRequest req) {
    return ListView(
      key: const ValueKey('accepted'),
      padding: const EdgeInsets.all(28),
      children: [
        StatusTag('Đã có đơn vị tiếp nhận', bg: Colors.blue.shade50, fg: Colors.blue.shade700),
        const SizedBox(height: 24),
        Text(req.garageName ?? 'Đang kết nối...', style: T.h2(context)),
        Text('Đơn vị cứu hộ đang di chuyển tới vị trí của bạn.', style: T.body(context, C.muted(context))),
        const SizedBox(height: 40),
        AppButton('Gọi cứu hộ', icon: Icons.phone, height: 56, onTap: () => callPhone(context, '115')),
        const SizedBox(height: 16),
        AppButton('Lập hồ sơ bảo hiểm', tone: Tone.soft, icon: Icons.verified_user_outlined, 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InsuranceReportScreen(initialSOS: req)))),
        const SizedBox(height: 40),
        AppButton('Đóng', tone: Tone.ghost, onTap: () => FirebaseService.updateSOSStatus(req.id, 'done')),
      ],
    );
  }

  Widget _buildTimeoutUI(SOSRequest req) {
    return ListView(
      key: const ValueKey('timeout'),
      padding: const EdgeInsets.all(28),
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.orange),
        const SizedBox(height: 24),
        Text('Không tìm thấy thợ', style: T.h2(context), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text('Hệ thống không tìm thấy đơn vị cứu hộ nào phản hồi trong khu vực của bạn.', textAlign: TextAlign.center),
        const SizedBox(height: 48),
        // SỬA AN TOÀN: Bỏ FittedBox, rút gọn nhãn, thêm hotline bên dưới
        AppButton('Gọi cứu hộ 116', icon: Icons.phone, height: 56, onTap: () => callPhone(context, '0896116116')),
        const SizedBox(height: 8),
        const Center(child: Text('Hotline: 0896.116.116', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),
        const SizedBox(height: 24),
        AppButton('Thử lại / Gửi yêu cầu mới', tone: Tone.soft, onTap: () => FirebaseService.updateSOSStatus(req.id, 'done')),
      ],
    );
  }
}

class _WaitingView extends StatefulWidget {
  final SOSRequest req;
  const _WaitingView({required this.req});
  @override
  State<_WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends State<_WaitingView> {
  Timer? _timer;
  int _sec = TIMEOUT_SECONDS;
  bool _ex = false;

  @override
  void initState() {
    super.initState();
    final diff = DateTime.now().difference(widget.req.createdAt).inSeconds;
    _sec = TIMEOUT_SECONDS - diff;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _sec--;
        if (_sec <= (TIMEOUT_SECONDS - SEARCH_LIMIT_SECONDS) && !_ex) {
          _ex = true;
          FirebaseService.db.collection('sos_requests').doc(widget.req.id).update({'status': 'expanded'});
        }
        if (_sec <= 0) {
          t.cancel();
          FirebaseService.updateSOSStatus(widget.req.id, 'timeout');
        }
      });
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Center(child: Text(_ex ? 'Đang mở rộng phạm vi tìm kiếm...' : 'Đang tìm đơn vị cứu hộ...', style: T.small(context).copyWith(fontWeight: FontWeight.bold))),
        const SizedBox(height: 40),
        Center(child: _radarIndicator()),
        const SizedBox(height: 60),
        AppCard(
          child: Column(children: [
            _row('Mã đơn', widget.req.id.substring(0, 8).toUpperCase()),
            _row('Thời gian', DateFormat('HH:mm:ss').format(widget.req.createdAt)),
            _row('Xe', widget.req.vehicleModel),
          ]),
        ),
        const SizedBox(height: 40),
        // SỬA AN TOÀN: Bỏ FittedBox, rút gọn nhãn, thêm hotline bên dưới
        AppButton('Gọi cứu hộ 116', tone: Tone.soft, icon: Icons.phone, height: 52, onTap: () => callPhone(context, '0896116116')),
        const SizedBox(height: 8),
        const Center(child: Text('Hotline: 0896.116.116', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
        const SizedBox(height: 24),
        AppButton('Hủy yêu cầu', tone: Tone.ghost, onTap: () => FirebaseService.cancelSOS(widget.req.id)),
      ],
    );
  }

  Widget _radarIndicator() {
    return Stack(alignment: Alignment.center, children: [
      for(var i=0; i<3; i++)
        Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.brand(context).withValues(alpha: 0.2), width: 1))).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1,1), end: const Offset(2.5, 2.5), duration: const Duration(seconds: 2), delay: Duration(milliseconds: (i*600).toInt())).fade(begin: 0.5, end: 0),
      Container(
        width: 120, height: 120,
        decoration: BoxDecoration(color: C.brand(context), shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.brand(context).withValues(alpha: 0.3), blurRadius: 20)]),
        child: Center(child: Text('${(_sec ~/ 60).toString().padLeft(2,'0')}:${(_sec % 60).toString().padLeft(2,'0')}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
      ),
    ]);
  }

  Widget _row(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: T.caption(context)), Text(v, style: T.small(context).copyWith(fontWeight: FontWeight.bold))]));
}
