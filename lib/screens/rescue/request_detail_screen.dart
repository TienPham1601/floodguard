import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import '../../data/places.dart';
import '../../data/directions.dart';
import '../../utils.dart';
import 'already_taken_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  final String id;
  const RequestDetailScreen({super.key, required this.id});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  String _address = 'Đang tải vị trí...';
  double? _distKm;
  String? _durationText;
  bool _loadingAction = false;

  @override
  void initState() {
    super.initState();
    _loadExtraData();
  }

  Future<void> _loadExtraData() async {
    final doc = await FirebaseService.db.collection('sos_requests').doc(widget.id).get();
    if (!doc.exists) return;
    final req = SOSRequest.fromFirestore(doc);
    
    // Reverse Geocode
    final addr = await SearchService.reverseGeocode(req.latitude, req.longitude);
    
    // Tính khoảng cách/thời gian thực tế
    final myPos = await Geolocator.getCurrentPosition();
    final route = await RoutingService.fetchRoute(
      LatLng(myPos.latitude, myPos.longitude),
      LatLng(req.latitude, req.longitude),
    );

    if (mounted) {
      setState(() {
        _address = addr;
        if (route != null) {
          _distKm = route.distanceMeters / 1000;
          _durationText = route.durationText;
        } else {
          // Fallback nếu lỗi route
          _distKm = Geolocator.distanceBetween(myPos.latitude, myPos.longitude, req.latitude, req.longitude) / 1000;
          _durationText = '${(_distKm! * 2).round() + 5} phút';
        }
      });
    }
  }

  String _maskPlate(String plate) {
    if (plate.length < 4) return plate;
    return '${plate.substring(0, 3)}-***.**';
  }

  void _onAccept(SOSRequest req) async {
    setState(() => _loadingAction = true);
    try {
      await FirebaseService.acceptSOS(req.id, FirebaseService.auth.currentUser!.uid, 'Gara của bạn');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tiếp nhận yêu cầu thành công!')));
      }
    } catch (e) {
      if (e.toString().contains('ALREADY_TAKEN')) {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AlreadyTakenScreen()));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SOSRequest?>(
      stream: FirebaseService.streamSOSDetail(widget.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final req = snapshot.data!;
        final bool isAcceptedByMe = req.rescuerId == FirebaseService.auth.currentUser?.uid;
        final bool isPending = req.status == 'pending' || req.status == 'expanded';
        final bool unlocked = isAcceptedByMe;

        return Screen(
          bar: topBar(context, 'Yêu cầu #${req.id.substring(0, 6).toUpperCase()}',
              left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
          child: ListView(
            padding: const EdgeInsets.all(S.x4),
            children: [
              if (unlocked)
                const AlertBanner(level: Level.safe, icon: Icons.check_circle_outline, text: 'Bạn đã nhận yêu cầu này. Chủ xe đã được thông báo.')
              else if (!isPending && !unlocked)
                const AlertBanner(level: Level.warn, text: 'Yêu cầu này đã được đơn vị khác tiếp nhận.')
              else
                const AlertBanner(level: Level.danger, text: 'Xe ngập nước. Gửi cách đây ít phút.'),
              
              const SizedBox(height: S.x4),

              _MiniMapDisplay(
                lat: req.latitude,
                lng: req.longitude,
                unlocked: unlocked,
                distText: _distKm != null ? '${_distKm!.toStringAsFixed(1)} km' : '...',
                timeText: _durationText ?? '...',
              ),
              
              const SizedBox(height: S.x4),

              // Thông tin xe
              Container(
                decoration: BoxDecoration(
                  color: C.surface(context),
                  border: Border.all(color: unlocked ? C.safe(context) : C.line(context)),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(S.x4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(unlocked ? req.vehiclePlate : _maskPlate(req.vehiclePlate), style: T.title(context)),
                        const SizedBox(height: 2),
                        Text(req.vehicleModel, style: T.small(context)),
                      ]),
                    ),
                    StatusTag(unlocked ? 'Đã mở khoá' : 'Ngập ${req.waterCm}cm',
                        fg: unlocked ? C.safe(context) : C.danger(context),
                        bg: unlocked ? C.safeBg(context) : C.dangerBg(context)),
                  ]),
                  const SizedBox(height: 12),
                  _kv(context, 'Khu vực', _address),
                  if (unlocked) _kv(context, 'Toạ độ', '${req.latitude.toStringAsFixed(5)}, ${req.longitude.toStringAsFixed(5)}', mono: true),
                  _kv(context, 'Chủ xe', req.requesterName ?? 'Ẩn danh', masked: !unlocked),
                  _kv(context, 'Điện thoại', req.requesterPhone ?? '...', mono: unlocked, masked: !unlocked),
                ]),
              ),
              const SizedBox(height: S.x4),

              // Trạng thái thiết bị
              _DeviceStatusCard(req: req),
              
              const SizedBox(height: S.x4),

              if (unlocked) ...[
                Row(children: [
                  Expanded(child: AppButton('Gọi', icon: Icons.phone, tone: Tone.ghost,
                      onTap: () => callPhone(context, req.requesterPhone ?? ''))),
                  const SizedBox(width: S.x3),
                  Expanded(
                    flex: 2,
                    child: AppButton('Dẫn đường', icon: Icons.navigation, onTap: () {
                       // Logic dẫn đường sẽ được xử lý tại RescueMapScreen
                       Navigator.pop(context);
                    }),
                  ),
                ]),
                const SizedBox(height: S.x3),
                const AlertBanner(text: 'Hãy cập nhật trạng thái thường xuyên để chủ xe yên tâm.'),
              ] else if (isPending) ...[
                if (_loadingAction)
                  const Center(child: CircularProgressIndicator())
                else
                  AppButton('Nhận yêu cầu', icon: Icons.lock_open, onTap: () => _onAccept(req)),
                const SizedBox(height: S.x2),
                AppButton('Bỏ qua yêu cầu này', tone: Tone.ghost, onTap: () => Navigator.pop(context)),
                const SizedBox(height: S.x2),
                Text('Khi nhận, bạn thấy toạ độ chính xác và liên hệ chủ xe.\nViệc nhận được ghi vào nhật ký hệ thống.',
                    textAlign: TextAlign.center, style: T.caption(context)),
              ],
            ],
          ),
        );
      }
    );
  }

  Widget _kv(BuildContext c, String k, String v, {bool mono = false, bool masked = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: T.small(c)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(masked ? 'Hiện sau khi nhận' : v,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: masked
                  ? T.small(c).copyWith(fontStyle: FontStyle.italic, color: Colors.grey)
                  : (mono ? T.monoSm(c, C.ink(c)) : T.body(c).copyWith(fontSize: 13, fontWeight: FontWeight.w500))),
        ),
      ]),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final SOSRequest req;
  const _DeviceStatusCard({required this.req});

  @override
  Widget build(BuildContext context) {
    // Nếu không có bất kỳ dữ liệu thiết bị nào
    if (req.powerCut == null && req.intakeClosed == null && req.personInside == null) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.router_outlined, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Text('Chưa có dữ liệu từ thiết bị ESP32', style: T.small(context, Colors.grey)),
          ]),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(children: [
        _statusRow(context, 'Nguồn điện', req.powerCut == true ? 'Đã ngắt tự động' : 'Bình thường', req.powerCut == true ? C.danger(context) : C.safe(context)),
        _statusRow(context, 'Cổ hút', req.intakeClosed == true ? 'Đã đóng' : 'Mở', req.intakeClosed == true ? C.danger(context) : C.safe(context)),
        _statusRow(context, 'Người trong xe', req.personInside == true ? 'Có người' : 'Không có', req.personInside == true ? C.danger(context) : C.safe(context)),
        if (req.waterRisingSpeed != null)
           _statusRow(context, 'Tốc độ nước dâng', '${req.waterRisingSpeed!.toStringAsFixed(1)} cm/phút', C.warn(context)),
      ]),
    );
  }

  Widget _statusRow(BuildContext c, String k, String v, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line(c)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: T.small(c)),
        Text(v, style: T.body(c, color).copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _MiniMapDisplay extends StatelessWidget {
  final double lat, lng;
  final bool unlocked;
  final String distText, timeText;
  const _MiniMapDisplay({required this.lat, required this.lng, required this.unlocked, required this.distText, required this.timeText});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line(context)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 48, color: Colors.white),
          // Ở đây có thể tích hợp bản đồ thật thu nhỏ nếu cần, hiện tại giữ placeholder đẹp
          if (!unlocked) 
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 2),
              ),
              width: 100, height: 100,
              child: const Center(child: Icon(Icons.location_on, color: Colors.red, size: 32)),
            ),
          Positioned(
            bottom: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Text('$distText · $timeText', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
}
