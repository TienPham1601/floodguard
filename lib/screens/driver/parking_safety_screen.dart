import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';

class ParkingSafetyScreen extends StatelessWidget {
  const ParkingSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const score = 46; // 0..100, càng thấp càng rủi ro
    final color = score >= 70 ? C.safe(context) : (score >= 40 ? C.warn(context) : C.danger(context));
    final bg = score >= 70 ? C.safeBg(context) : (score >= 40 ? C.warnBg(context) : C.dangerBg(context));

    return Screen(
      bar: topBar(context, 'Điểm đỗ hiện tại',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          AppCard(
            child: Row(children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$score', style: T.mono(context, color).copyWith(fontSize: 34)),
                  const SizedBox(height: 2),
                  Text('RỦI RO CAO', style: T.caption(context, color).copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Nguyễn Hữu Cảnh', style: T.title(context).copyWith(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Bình Thạnh, TP.HCM\nBạn đã đỗ ở đây 40 phút', style: T.small(context).copyWith(height: 1.6)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: S.x4),

          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vì sao', style: T.title(context).copyWith(fontSize: 15)),
              const SizedBox(height: 6),
              _kv(context, 'Dự báo mưa 6 giờ tới', 'Mưa to, 85%', C.danger(context)),
              _kv(context, 'Lịch sử ngập quanh đây', '12 lần / 6 tháng', C.warn(context)),
              _kv(context, 'Độ cao địa hình', 'Thấp hơn xung quanh', C.warn(context)),
              _kv(context, 'Ngập gần nhất', '03/07 · 45cm', C.ink(context)),
            ]),
          ),
          const SizedBox(height: S.x4),

          const AlertBanner(text: 'Khu vực này ngập trung bình 2 lần mỗi tháng vào mùa mưa.'),
          const SizedBox(height: S.x4),

          AppButton('Tìm chỗ đỗ an toàn hơn', icon: Icons.local_parking, onTap: () {}),
          const SizedBox(height: S.x4),

          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              _suggest(context, 'Bãi Landmark 81', '92'),
              _suggest(context, 'Bãi Vinhomes Central', '88'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext c, String k, String v, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line(c)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(k, style: T.small(c))),
        Text(v, style: T.body(c, color).copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _suggest(BuildContext c, String name, String score) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line(c)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(name, style: T.body(c)),
        StatusTag('AN TOÀN $score', fg: C.safe(c), bg: C.safeBg(c)),
      ]),
    );
  }
}
