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
import 'quote_input_screen.dart';

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
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadExtraData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadExtraData() async {
    final doc = await FirebaseService.db.collection('sos_requests').doc(widget.id).get();
    if (!doc.exists) return;
    final req = SOSRequest.fromFirestore(doc);
    
    final myPos = await Geolocator.getCurrentPosition();
    final route = await RoutingService.fetchRoute(
      LatLng(myPos.latitude, myPos.longitude),
      LatLng(req.latitude, req.longitude),
    );

    final addr = await SearchService.reverseGeocode(req.latitude, req.longitude);

    if (mounted && !_isDisposed) {
      setState(() {
        _address = addr;
        if (route != null) {
          _distKm = route.distanceMeters / 1000;
          _durationText = route.durationText;
        }
      });
    }
  }

  String _maskPlate(String plate) {
    if (plate.length < 4) return plate;
    return '${plate.substring(0, 3)}-***.**';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SOSRequest?>(
      stream: FirebaseService.streamSOSDetail(widget.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) return const Scaffold(body: Center(child: Text('Yêu cầu không còn tồn tại.')));

        final req = snapshot.data!;
        final bool isAcceptedByMe = req.rescuerId == FirebaseService.auth.currentUser?.uid;
        final bool isPending = req.status == 'pending' || req.status == 'expanded' || req.status == 'quoted';
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
              else if (req.status == 'quoted' && !unlocked)
                const AlertBanner(level: Level.warn, text: 'Đơn này đã có thợ báo giá. Bạn vẫn có thể báo giá cạnh tranh.')
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
                  _kv(context, 'Chủ xe', req.requesterName ?? 'Chủ xe', masked: !unlocked),
                  _kv(context, 'Điện thoại', req.requesterPhone ?? '...', mono: unlocked, masked: !unlocked),
                ]),
              ),
              const SizedBox(height: S.x4),

              _DeviceStatusCard(req: req),
              
              const SizedBox(height: S.x4),

              if (unlocked) ...[
                Row(children: [
                  Expanded(child: AppButton('Gọi chủ xe', icon: Icons.phone, tone: Tone.ghost,
                      onTap: () => callPhone(context, req.requesterPhone ?? ''))),
                  const SizedBox(width: S.x3),
                  Expanded(
                    flex: 2,
                    child: AppButton('Chỉ đường ngay', icon: Icons.navigation, onTap: () {
                       ORSNavigation.target.value = MapTarget(
                         name: req.vehiclePlate,
                         subtitle: req.vehicleModel,
                         pos: LatLng(req.latitude, req.longitude),
                       );
                       Navigator.of(context).popUntil((route) => route.isFirst);
                    }),
                  ),
                ]),
              ] else if (isPending) ...[
                AppButton('BÁO GIÁ & NHẬN ĐƠN', height: 60, icon: Icons.request_quote_outlined, onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteInputScreen(req: req, distText: _distKm != null ? '${_distKm!.toStringAsFixed(1)}km' : '...', timeText: _durationText ?? '...')));
                }),
                const SizedBox(height: S.x2),
                AppButton('Bỏ qua', tone: Tone.ghost, onTap: () => Navigator.pop(context)),
                const SizedBox(height: S.x2),
                Text('Khi gửi báo giá, chủ xe sẽ thấy thông tin của bạn.\nBạn chỉ thấy SĐT chính xác khi họ đồng ý.',
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
    if (req.powerCut == null && req.intakeClosed == null && req.personInside == null) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.router_outlined, color: Colors.grey.shade400, size: 18),
            const SizedBox(width: 12),
            Text('Chưa có dữ liệu từ thiết bị ESP32', style: T.small(context, Colors.grey)),
          ]),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(children: [
        _row(context, 'Nguồn điện', req.powerCut == true ? 'Đã ngắt' : 'Bình thường', req.powerCut == true ? C.danger(context) : C.safe(context)),
        _row(context, 'Cổ hút', req.intakeClosed == true ? 'Đã đóng' : 'Mở', req.intakeClosed == true ? C.danger(context) : C.safe(context)),
        _row(context, 'Người trong xe', req.personInside == true ? 'CÓ' : 'Không', req.personInside == true ? C.danger(context) : C.safe(context)),
      ]),
    );
  }

  Widget _row(BuildContext c, String k, String v, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line(c), width: 0.5))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: T.small(c)),
        Text(v, style: T.body(c, color).copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
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
      height: 150,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line(context))),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 48, color: Colors.white),
          if (!unlocked) 
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withValues(alpha: 0.1), border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 2)),
              width: 90, height: 90,
              child: const Center(child: Icon(Icons.location_on, color: Colors.red, size: 28)),
            ),
          Positioned(bottom: 12, left: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: Text('$distText · $timeText', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
        ],
      ),
    );
  }
}
