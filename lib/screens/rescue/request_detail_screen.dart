import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/rescue_data.dart';
import '../../utils.dart';

class RequestDetailScreen extends StatefulWidget {
  final String id;
  const RequestDetailScreen({super.key, required this.id});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final req = rescue.byId(widget.id);
    final unlocked = req.unlocked;

    return Screen(
      bar: topBar(context, 'Yêu cầu #${req.id}',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          if (unlocked)
            const AlertBanner(level: Level.safe, icon: Icons.check_circle_outline, text: 'Bạn đã nhận yêu cầu này. Chủ xe đã được thông báo.')
          else
            const AlertBanner(level: Level.danger, text: 'Xe ngập nước, đã ngắt nguồn. Gửi cách đây ít phút.'),
          const SizedBox(height: S.x4),

          // bản đồ: vùng ~300m khi chưa nhận, tuyến đường khi đã nhận
          _MiniMap(unlocked: unlocked, waterCm: req.waterCm, distanceKm: req.distanceKm),
          const SizedBox(height: S.x4),

          // thông tin xe & chủ xe (tiết lộ theo giai đoạn)
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
                    Text(req.plate, style: T.title(context)),
                    const SizedBox(height: 2),
                    Text(unlocked ? req.model : '${req.vehicleType} · khoảng sáng gầm 150mm', style: T.small(context)),
                  ]),
                ),
                StatusTag(unlocked ? 'Đã mở khoá' : 'Ngập ${req.waterCm}cm',
                    fg: unlocked ? C.safe(context) : C.danger(context),
                    bg: unlocked ? C.safeBg(context) : C.dangerBg(context)),
              ]),
              const SizedBox(height: 12),
              _kv(context, 'Khu vực', req.locationLabel),
              if (unlocked) _kv(context, 'Toạ độ', req.coords, mono: true),
              _kv(context, 'Chủ xe', req.owner, masked: !unlocked),
              _kv(context, 'Điện thoại', req.phone, mono: unlocked, masked: !unlocked),
            ]),
          ),
          const SizedBox(height: S.x4),

          // tình trạng xe — hiện ở cả hai giai đoạn
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              _statusRow(context, 'Nguồn điện', req.powerCut ? 'Đã ngắt tự động' : 'Bình thường', req.powerCut ? C.danger(context) : C.safe(context)),
              _statusRow(context, 'Cổ hút', req.intakeClosed ? 'Đã đóng' : 'Mở', req.intakeClosed ? C.danger(context) : C.safe(context)),
              _statusRow(context, 'Người trong xe', req.personInside ? 'Có' : 'Không', req.personInside ? C.danger(context) : C.safe(context)),
              _statusRow(context, 'Nước còn dâng', req.risingRate, C.warn(context)),
            ]),
          ),
          const SizedBox(height: S.x4),

          if (unlocked) ...[
            Row(children: [
              Expanded(child: AppButton('Gọi', icon: Icons.phone, tone: Tone.ghost,
                  onTap: () => callPhone(context, req.ownerPhone))),
              const SizedBox(width: S.x3),
              Expanded(
                flex: 2,
                child: AppButton('Bắt đầu dẫn đường', icon: Icons.navigation, onTap: () {
                  navigateTo.value = req;
                  Navigator.pop(context);
                }),
              ),
            ]),
            const SizedBox(height: S.x3),
            const AlertBanner(text: 'Nếu không cập nhật trạng thái trong 15 phút, yêu cầu sẽ tự quay lại hàng chờ.'),
          ] else ...[
            AppButton('Nhận yêu cầu', icon: Icons.lock_open, onTap: () {
              rescue.accept(req.id);
              setState(() {});
            }),
            const SizedBox(height: S.x2),
            AppButton('Bỏ qua yêu cầu này', tone: Tone.ghost, onTap: () {
              rescue.dismiss(req.id);
              Navigator.pop(context);
            }),
            const SizedBox(height: S.x2),
            Text('Khi nhận, bạn thấy toạ độ chính xác và liên hệ chủ xe.\nViệc nhận được ghi vào nhật ký hệ thống.',
                textAlign: TextAlign.center, style: T.caption(context)),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext c, String k, String v, {bool mono = false, bool masked = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: T.small(c)),
        Flexible(
          child: Text(v,
              textAlign: TextAlign.right,
              style: masked
                  ? T.small(c).copyWith(fontStyle: FontStyle.italic)
                  : (mono ? T.monoSm(c, C.ink(c)) : T.body(c).copyWith(fontSize: 13, fontWeight: FontWeight.w500))),
        ),
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

class _MiniMap extends StatelessWidget {
  final bool unlocked;
  final int waterCm;
  final double distanceKm;
  const _MiniMap({required this.unlocked, required this.waterCm, required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        decoration: BoxDecoration(border: Border.all(color: C.line(context)), borderRadius: BorderRadius.circular(16)),
        child: Stack(children: [
          Container(color: const Color(0xFFE8EDF2)),
          CustomPaint(size: Size.infinite, painter: _MapPainter(unlocked: unlocked, danger: C.danger(context), brand: C.brand(context))),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: C.surface(context),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
              ),
              child: Text(unlocked ? '${distanceKm.toStringAsFixed(1)} km · 9 phút' : '~${distanceKm.toStringAsFixed(1)} km · khoảng 9 phút',
                  style: T.body(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool unlocked;
  final Color danger, brand;
  _MapPainter({required this.unlocked, required this.danger, required this.brand});

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 62, 400, 18), road);
    canvas.drawRect(const Rect.fromLTWH(150, 0, 16, 200), road);
    final blk = Paint()..color = const Color(0xFFDDE4EB);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(16, 90, 110, 60), const Radius.circular(3)), blk);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(190, 90, 160, 60), const Radius.circular(3)), blk);

    if (unlocked) {
      // tuyến đường + marker chính xác
      final route = Paint()
        ..color = brand
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(60, 104), const Offset(236, 78), route);
      final mk = Paint()..color = danger;
      canvas.drawCircle(const Offset(250, 78), 12, mk);
      final border = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(const Offset(250, 78), 12, border);
    } else {
      // vùng ước lượng ~300m
      final area = Paint()..color = danger.withValues(alpha: 0.15);
      final areaBorder = Paint()
        ..color = danger.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(const Offset(244, 88), 48, area);
      canvas.drawCircle(const Offset(244, 88), 48, areaBorder);
    }
    // vị trí đội cứu hộ
    final me = Paint()..color = brand;
    canvas.drawCircle(const Offset(52, 104), 8, me);
    final meBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(52, 104), 8, meBorder);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.unlocked != unlocked;
}
