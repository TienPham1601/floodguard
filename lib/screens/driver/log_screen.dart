import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Nhật ký',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _label(context, 'HÔM NAY · 25/07'),
          _row(context, C.danger(context), 'Tự động đóng cổ hút, ngắt nguồn', 'Mực nước 38cm · Nguyễn Hữu Cảnh', '15:38'),
          _row(context, C.danger(context), 'Vượt ngưỡng nguy hiểm', '35cm → 38cm', '15:37'),
          _row(context, C.warn(context), 'Vượt ngưỡng cảnh báo', '20cm → 24cm', '15:06'),
          _row(context, C.brand(context), 'Minh Thư mở lại cổ hút', 'Thao tác thủ công', '14:20'),
          _row(context, C.safe(context), 'Về mức an toàn', '18cm', '11:44'),
          _label(context, 'HÔM QUA · 24/07'),
          _row(context, C.warn(context), 'Độ ẩm cabin cao kéo dài', '78% liên tục 26 giờ · nguy cơ ẩm mốc', '20:15'),
          _row(context, C.brand(context), 'Thiết bị kết nối lại', 'WiFi nhà', '18:30'),
          Padding(
            padding: const EdgeInsets.all(S.x4),
            child: Column(children: [
              const AlertBanner(
                level: Level.safe,
                icon: Icons.shield_outlined,
                text: 'Sự kiện an toàn được lưu 12 tháng và không xoá được, dùng làm bằng chứng bảo hiểm.',
              ),
              const SizedBox(height: S.x3),
              AppButton('Xuất nhật ký (PDF)', tone: Tone.ghost, height: 46, onTap: () {}),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Text(t, style: T.caption(c).copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _row(BuildContext c, Color dot, String title, String sub, String time) {
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
        Text(time, style: T.small(c)),
      ]),
    );
  }
}
