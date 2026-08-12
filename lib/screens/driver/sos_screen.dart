import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'insurance_report_screen.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../utils.dart';
import '../../data/location_service.dart';
import '../../data/places.dart';
import '../../data/firebase_service.dart';

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
  String? _lastStatus;

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
            
            if (activeSOS?.status == 'done') return _RatingScreen(req: activeSOS!);

            final bool isReallyActive = activeSOS != null && 
                ['pending', 'quoted', 'accepted', 'processing', 'arrived', 'expanded'].contains(activeSOS.status);

            if (activeSOS != null && _lastStatus == 'pending' && activeSOS.status == 'accepted') {
              HapticFeedback.vibrate();
            }
            _lastStatus = activeSOS?.status;

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

  Widget _buildActiveUI(BuildContext context, SOSRequest req) {
    if (req.status == 'quoted') return _QuoteSelectionView(req: req);
    if (['accepted', 'processing', 'arrived'].contains(req.status)) return _TrackingView(req: req);
    if (req.status == 'timeout') return _buildTimeoutUI(req);
    return _WaitingView(req: req);
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
        AppButton('Gọi cứu hộ 116', icon: Icons.phone, height: 56, onTap: () => callPhone(context, '0896116116')),
        const SizedBox(height: 8),
        const Center(child: Text('Hotline: 0896.116.116', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),
        const SizedBox(height: 24),
        AppButton('Thử lại / Gửi yêu cầu mới', tone: Tone.soft, onTap: () => FirebaseService.updateSOSStatus(req.id, 'done')),
      ],
    );
  }
}

class _QuoteSelectionView extends StatelessWidget {
  final SOSRequest req;
  const _QuoteSelectionView({required this.req});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SOSQuote>>(
      stream: FirebaseService.streamQuotes(req.id),
      builder: (context, snapshot) {
        final quotes = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.request_quote_outlined, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('Đã có đơn vị báo giá', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Đề xuất cứu hộ', style: T.h2(context), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Chọn đơn vị phù hợp nhất với bạn', style: T.body(context, Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 32),

            if (quotes.isEmpty) 
               const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else
               ...quotes.map((q) => _quoteCard(context, q)),

            const SizedBox(height: 24),
            AppButton('Hủy yêu cầu SOS', tone: Tone.ghost, onTap: () => FirebaseService.cancelSOS(req.id)),
          ],
        );
      }
    );
  }

  Widget _quoteCard(BuildContext context, SOSQuote q) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 24, backgroundColor: C.brandBg(context), child: Text(q.garageName.isNotEmpty ? q.garageName[0] : 'G', style: T.title(context).copyWith(color: C.brand(context)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.garageName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(children: [
              const Icon(Icons.star, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text(q.rating > 0 ? '${q.rating.toStringAsFixed(1)} (${q.ratingCount} đánh giá)' : 'Chưa có đánh giá', style: T.caption(context)),
            ]),
          ])),
          IconButton(icon: const Icon(Icons.phone, color: Colors.blue), onPressed: () => callPhone(context, q.rescuerPhone)),
        ]),
        const Divider(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('GIÁ DỊCH VỤ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(currencyFormat.format(q.price), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blue)),
        ]),
        if (q.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(q.note, style: T.small(context, Colors.grey.shade700))),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: AppButton('Từ chối', tone: Tone.soft, onTap: () => FirebaseService.declineQuote(req.id, q.rescuerId))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: AppButton('ĐỒNG Ý', onTap: () => FirebaseService.acceptQuote(req.id, q))),
        ]),
      ]),
    ).animate().fade().slideY(begin: 0.1);
  }
}

class _TrackingView extends StatelessWidget {
  final SOSRequest req;
  const _TrackingView({required this.req});

  @override
  Widget build(BuildContext context) {
    String statusText = 'Đang kết nối...';
    IconData statusIcon = Icons.handshake_outlined;
    Color statusColor = Colors.blue;

    if (req.status == 'accepted') {
      statusText = 'Đã có đội cứu hộ tiếp nhận';
      statusIcon = Icons.check_circle;
    } else if (req.status == 'processing') {
      statusText = 'Cứu hộ đang di chuyển tới';
      statusIcon = Icons.directions_car_filled;
    } else if (req.status == 'arrived') {
      statusText = 'Cứu hộ đã tới hiện trường';
      statusIcon = Icons.location_on;
      statusColor = Colors.green;
    }

    return ListView(
      key: const ValueKey('tracking'),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(req.garageName ?? 'Đơn vị cứu hộ', style: T.h2(context), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Mã đơn: ${req.id.substring(0, 8).toUpperCase()}', style: T.caption(context), textAlign: TextAlign.center),
        
        const SizedBox(height: 48),
        _trackingMapPlaceholder(context),
        
        const SizedBox(height: 48),
        AppCard(
          child: Column(children: [
            _row(context, 'Thợ xử lý', req.rescuerName ?? 'Kỹ thuật viên'),
            _row(context, 'Khoảng cách', _calcRescuerDist()),
            _row(context, 'Thời gian tới', 'Dự kiến 10-15 phút'),
          ]),
        ),
        
        const SizedBox(height: 40),
        Column(children: [
          _callRescuerButton(context),
          const SizedBox(height: 12),
          AppButton(
            'Gọi cứu hộ 116 (Dự phòng)', 
            tone: Tone.soft,
            icon: Icons.support_agent, 
            height: 48, 
            onTap: () => callPhone(context, '0896116116')
          ),
          const SizedBox(height: 16),
          AppButton(
            'Lập hồ sơ bảo hiểm', 
            tone: Tone.ghost, 
            icon: Icons.verified_user_outlined, 
            height: 52, 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InsuranceReportScreen(initialSOS: req)))
          ),
        ]),
        const SizedBox(height: 20),
        if (req.status == 'arrived')
          AppButton('Xác nhận hoàn thành', tone: Tone.brand, onTap: () => FirebaseService.updateSOSStatus(req.id, 'done'))
        else
          AppButton('Hủy yêu cầu', tone: Tone.ghost, onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Hủy cứu hộ?'), content: const Text('Bạn có chắc chắn muốn hủy yêu cầu cứu hộ này không?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hủy ngay', style: TextStyle(color: Colors.red)))]));
            if (ok == true) FirebaseService.cancelSOS(req.id);
          }),
      ],
    );
  }

  Widget _callRescuerButton(BuildContext context) {
    final String label = req.rescuerPhone != null && req.rescuerPhone!.isNotEmpty 
        ? 'Gọi Gara ${req.garageName ?? ""}' 
        : 'Chưa có số liên hệ';
    
    return Material(
      color: req.rescuerPhone != null ? C.brand(context) : Colors.grey.shade400,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: req.rescuerPhone != null ? () => callPhone(context, req.rescuerPhone!) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_forwarded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackingMapPlaceholder(BuildContext context) {
    final bool hasRescuerPos = req.rescuerLat != null && req.rescuerLng != null;
    
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.line(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(color: const Color(0xFFF0F2F5)),
            const Icon(Icons.map_outlined, size: 64, color: Colors.white),
            
            if (hasRescuerPos) ...[
              const Positioned(
                child: Icon(Icons.location_on, color: Colors.red, size: 32),
              ),
              _animatedRescuerMarker(),
            ],

            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                child: Text(
                  hasRescuerPos ? 'Đang chia sẻ vị trí cứu hộ...' : 'Đang đợi tín hiệu GPS từ cứu hộ...',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _animatedRescuerMarker() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, val, child) {
        return Align(
          alignment: const Alignment(-0.4, -0.4), 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue, 
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10 * val, spreadRadius: 5 * val)]
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 16),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                child: const Text('Cứu hộ', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  String _calcRescuerDist() {
    if (req.rescuerLat == null || req.rescuerLng == null) return 'Đang tính...';
    final d = Geolocator.distanceBetween(req.latitude, req.longitude, req.rescuerLat!, req.rescuerLng!) / 1000;
    return '${d.toStringAsFixed(1)} km';
  }

  Widget _row(BuildContext context, String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: T.caption(context)), Text(v, style: T.small(context).copyWith(fontWeight: FontWeight.bold))]));
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
      key: const ValueKey('waiting'),
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

class _RatingScreen extends StatefulWidget {
  final SOSRequest req;
  const _RatingScreen({required this.req});
  @override
  State<_RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<_RatingScreen> {
  double _stars = 0;
  final _commentCtrl = TextEditingController();
  final List<String> _selectedTags = [];
  bool _loading = false;

  final _allTags = ['Đúng giờ', 'Chuyên nghiệp', 'Giá hợp lý', 'Thân thiện', 'Nhiệt tình', 'Xử lý nhanh'];

  String _getStarText() {
    if (_stars == 0) return 'Vui lòng chọn số sao';
    if (_stars <= 1) return 'Rất tệ';
    if (_stars <= 2) return 'Tệ';
    if (_stars <= 3) return 'Bình thường';
    if (_stars <= 4) return 'Tốt';
    return 'Tuyệt vời';
  }

  void _submit() async {
    if (_stars == 0) return;
    setState(() => _loading = true);
    try {
      await FirebaseService.submitRating(
        sosId: widget.req.id,
        rescuerId: widget.req.rescuerId!,
        stars: _stars,
        comment: _commentCtrl.text.trim(),
        tags: _selectedTags,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skip() async {
    try {
      await FirebaseService.db.collection('sos_requests').doc(widget.req.id).update({'rated': true, 'status': 'rated'});
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final completedTime = widget.req.doneAt ?? DateTime.now();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 72, color: Colors.green).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  Text('Cứu hộ hoàn tất!', style: T.h2(context).copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text('Hoàn thành lúc ${DateFormat('HH:mm, dd/MM').format(completedTime)}', style: T.caption(context)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Thông tin dịch vụ
            AppCard(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Column(children: [
                Row(children: [
                  CircleAvatar(radius: 20, backgroundColor: C.brand(context).withValues(alpha: 0.1), child: Icon(Icons.garage, color: C.brand(context), size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.req.garageName ?? 'Đơn vị cứu hộ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Thợ: ${widget.req.rescuerName ?? "Kỹ thuật viên"}', style: T.caption(context)),
                  ])),
                ]),
                const Divider(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Xe: ${widget.req.vehiclePlate}', style: T.small(context)),
                  Text(currencyFormat.format(widget.req.quotedPrice ?? 0), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 16)),
                ]),
              ]),
            ),
            const SizedBox(height: 40),

            // Đánh giá sao
            Center(child: Text('Bạn thấy thế nào về dịch vụ?', style: T.title(context))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1.0;
                final isSelected = starValue <= _stars;
                return GestureDetector(
                  onTap: () => setState(() => _stars = starValue),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 52,
                      color: isSelected ? Colors.orange : Colors.grey.shade300,
                    ).animate(target: isSelected ? 1 : 0).scale(duration: 200.ms, curve: Curves.easeOutBack),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Center(child: Text(_getStarText(), style: TextStyle(color: _stars > 0 ? Colors.orange : Colors.grey, fontWeight: FontWeight.bold))),
            const SizedBox(height: 40),

            // Nhãn nhanh
            if (_stars > 0) ...[
               Text('Điều gì làm bạn hài lòng?', style: T.caption(context).copyWith(fontWeight: FontWeight.bold)),
               const SizedBox(height: 12),
               Wrap(
                 spacing: 8,
                 runSpacing: 8,
                 children: _allTags.map((tag) {
                   final isSelected = _selectedTags.contains(tag);
                   return FilterChip(
                     label: Text(tag, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.grey.shade700)),
                     selected: isSelected,
                     onSelected: (val) {
                       setState(() {
                         if (val) _selectedTags.add(tag);
                         else _selectedTags.remove(tag);
                       });
                     },
                     selectedColor: C.brand(context),
                     checkmarkColor: Colors.white,
                     backgroundColor: Colors.grey.shade100,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                   );
                 }).toList(),
               ),
               const SizedBox(height: 24),
            ],

            // Bình luận
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Chia sẻ trải nghiệm của bạn...',
                hintStyle: T.small(context, Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 48),

            // Nút bấm
            if (_loading) 
              const Center(child: CircularProgressIndicator())
            else ...[
              AppButton(
                'GỬI ĐÁNH GIÁ', 
                onTap: _stars > 0 ? _submit : null,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _skip, 
                  child: Text('Bỏ qua', style: TextStyle(color: Colors.grey.shade400))
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
