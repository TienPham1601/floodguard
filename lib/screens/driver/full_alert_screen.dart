import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../utils.dart';

/// Màn cảnh báo toàn màn hình. Dùng cho hai tình huống nguy cấp nhất:
/// đang lái qua vùng ngập, và còn người trong xe khi cabin quá nóng.
/// Cố ý phá bố cục thường: nền đỏ kín, chữ rất lớn, chỉ hai lựa chọn.
class FullAlertScreen extends StatelessWidget {
  final String eyebrow;
  final String headline;
  final List<Widget> figures;
  final List<String> instructions;
  final String primaryLabel;
  final IconData? primaryIcon;
  final String secondaryLabel;
  final String primaryPhone;

  const FullAlertScreen({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.figures,
    required this.instructions,
    required this.primaryLabel,
    this.primaryIcon,
    required this.secondaryLabel,
    required this.primaryPhone,
  });

  /// Nước vượt ngưỡng khi đang lái.
  factory FullAlertScreen.flood({required int cm}) {
    return FullAlertScreen(
      eyebrow: 'NGUY HIỂM',
      headline: 'Dừng xe ngay.\nKhông đề lại máy.',
      figures: [_Figure(value: '$cm', unit: 'cm — vượt ngưỡng an toàn của xe bạn', big: true)],
      instructions: const [
        'Đã ngắt đánh lửa',
        'Đã ghi vị trí vào nhật ký',
        'Hạ kính xuống trước khi thoát xe',
      ],
      primaryLabel: 'GỌI CỨU HỘ NGAY',
      primaryIcon: Icons.phone,
      primaryPhone: '19001234',
      secondaryLabel: 'Tôi đã an toàn',
    );
  }

  /// Còn người trong xe, cabin đang nóng lên.
  factory FullAlertScreen.person({required double tempC, required int minutes}) {
    return FullAlertScreen(
      eyebrow: 'KHẨN CẤP',
      headline: 'Còn người trong xe.\nQuay lại ngay.',
      figures: [
        _Figure(value: tempC.toStringAsFixed(1), unit: '°C trong cabin'),
        _Figure(value: '$minutes', unit: 'phút kể từ khi bạn rời xe'),
      ],
      instructions: const [
        'Radar phát hiện chuyển động thở',
        'Nhiệt độ tăng 1,4°C mỗi phút',
        'Còi trên xe đang kêu',
      ],
      primaryLabel: 'GỌI 115',
      primaryIcon: Icons.phone,
      primaryPhone: '115',
      secondaryLabel: 'Tôi đang quay lại xe',
    );
  }

  @override
  Widget build(BuildContext context) {
    final red = C.danger(context);
    return Scaffold(
      backgroundColor: red,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(eyebrow,
                    style: T.label(context, Colors.white.withValues(alpha: 0.85))
                        .copyWith(fontSize: 13, letterSpacing: 3)),
                const SizedBox(height: 10),
                Text(headline,
                    style: T.h2(context).copyWith(color: Colors.white, fontSize: 30, height: 1.25)),
                const SizedBox(height: 34),
                Row(children: [
                  for (int i = 0; i < figures.length; i++) ...[
                    figures[i],
                    if (i < figures.length - 1) const SizedBox(width: 28),
                  ],
                ]),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(S.x4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in instructions)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(line, style: T.body(context, Colors.white).copyWith(fontSize: 14)),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                _bigButton(context, primaryLabel, primaryIcon, filled: true, red: red,
                    onTap: () => callPhone(context, primaryPhone)),
                const SizedBox(height: S.x3),
                _bigButton(context, secondaryLabel, null, filled: false, red: red,
                    onTap: () => Navigator.maybePop(context)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigButton(BuildContext c, String label, IconData? icon,
      {required bool filled, required Color red, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: filled ? 56 : 52,
      child: Material(
        color: filled ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: filled
                ? null
                : BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(14),
                  ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: filled ? red : Colors.white),
                const SizedBox(width: 9),
              ],
              Text(label,
                  style: T.label(c, filled ? red : Colors.white)
                      .copyWith(fontSize: filled ? 17 : 15, fontWeight: filled ? FontWeight.w700 : FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String value, unit;
  final bool big;
  const _Figure({required this.value, required this.unit, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: T.big(context, Colors.white).copyWith(fontSize: big ? 76 : 52)),
        const SizedBox(height: 5),
        Text(unit,
            style: T.body(context, Colors.white.withValues(alpha: 0.85)).copyWith(fontSize: 13, height: 1.4)),
      ]),
    );
  }
}
