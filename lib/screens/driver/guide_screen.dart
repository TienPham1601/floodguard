import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static const _steps = [
    ('Tuyệt đối không đề lại máy', 'Nước đã vào xi-lanh. Đề máy sẽ làm gãy thanh truyền, chi phí sửa lên tới hàng chục triệu.'),
    ('Hạ kính xuống ngay', 'Mất điện là kính không hạ được nữa, và cửa không mở được do áp lực nước bên ngoài.'),
    ('Tháo cọc âm ắc-quy', 'Ngăn chập điện làm hỏng hộp điều khiển. Nếu có thiết bị FloodGuard, việc này đã tự động.'),
    ('Rời xe khi nước qua nửa bánh', 'Tài sản thay được, người thì không. Đừng ở lại trong xe chờ nước rút.'),
    ('Chụp ảnh trước khi kéo xe đi', 'Bảo hiểm cần ảnh hiện trường có mực nước. App tự đính kèm nhật ký và toạ độ.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Cẩm nang',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          const AlertBanner(level: Level.danger, text: 'Đọc nhanh. Mỗi phút chậm trễ làm hỏng hóc nặng thêm.'),
          const SizedBox(height: S.x3),
          for (int i = 0; i < _steps.length; i++) ...[
            _card(context, i + 1, _steps[i].$1, _steps[i].$2),
            if (i < _steps.length - 1) const SizedBox(height: S.x3),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext c, int n, String title, String body) {
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.dangerBg(c), borderRadius: BorderRadius.circular(9)),
          child: Text('$n', style: T.label(c, C.danger(c))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.title(c).copyWith(fontSize: 16)),
            const SizedBox(height: 5),
            Text(body, style: T.small(c).copyWith(height: 1.6)),
          ]),
        ),
      ]),
    );
  }
}
