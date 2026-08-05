import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';

class RescueHistoryScreen extends StatelessWidget {
  const RescueHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Lịch sử cứu hộ',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.all(S.x4),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _stat(context, '47', 'lượt hoàn tất'),
                _stat(context, '31', 'do ngập nước'),
                _stat(context, '6,4', 'phút phản hồi'),
              ]),
            ),
          ),
          _sectionLabel(context, 'HÔM NAY · 25/07'),
          _row(context, '51A-123.45 · Toyota Vios', 'Ngập 38cm · Nguyễn Hữu Cảnh', '15:43', '28 phút', C.safe(context)),
          _row(context, '59F-887.21 · Honda City', 'Ngập 41cm · Nguyễn Hữu Cảnh', '15:49', '34 phút', C.safe(context)),
          _row(context, '51G-204.77 · Mazda 3', 'Chủ xe tự xử lý được', '15:55', 'đã huỷ', C.muted(context)),
          _sectionLabel(context, 'HÔM QUA · 24/07'),
          _row(context, '51H-908.12 · Kia Morning', 'Chết máy do ngập · Ung Văn Khiêm', '18:20', '41 phút', C.safe(context)),
          _row(context, '30A-556.71 · Ford Ranger', 'Kéo xe · Điện Biên Phủ', '14:06', '52 phút', C.safe(context)),
          Padding(
            padding: const EdgeInsets.all(S.x4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: C.bg(context), borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lock_outline, size: 16, color: C.muted(context)),
                const SizedBox(width: 9),
                Expanded(child: Text('Tên và số điện thoại chủ xe đã được thu hồi sau 24 giờ.', style: T.caption(context))),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: AppButton('Xuất báo cáo tháng (PDF)', tone: Tone.ghost, height: 46, onTap: () {}),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext c, String value, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: T.mono(c).copyWith(fontSize: 24)),
      Text(label, style: T.caption(c)),
    ]);
  }

  Widget _sectionLabel(BuildContext c, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(text, style: T.caption(c).copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _row(BuildContext c, String title, String sub, String time, String dur, Color dot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: C.surface(c),
        border: Border(bottom: BorderSide(color: C.line(c)))),
      child: Row(children: [
        Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.body(c).copyWith(fontWeight: FontWeight.w500)),
            Text(sub, style: T.small(c)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(time, style: T.small(c)),
          Text(dur, style: T.caption(c).copyWith(fontSize: 11)),
        ]),
      ]),
    );
  }
}
