import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';

/// R5 — hai đơn vị cùng bấm nhận, ai trước được việc.
/// Người sau thấy màn này, kèm luật 15 phút không cập nhật thì yêu cầu về hàng chờ.
class AlreadyTakenScreen extends StatelessWidget {
  final String requestId;
  final String maskedPlate;
  final String area;
  final String takenBy;
  final String takenAt;
  final int secondsLate;

  const AlreadyTakenScreen({
    super.key,
    this.requestId = '2471',
    this.maskedPlate = '51A-***.**',
    this.area = 'Nguyễn Hữu Cảnh',
    this.takenBy = 'Cứu hộ Thành Long',
    this.takenAt = '15:43',
    this.secondsLate = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Yêu cầu #$requestId',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: Padding(
        padding: const EdgeInsets.all(S.x4),
        child: Column(children: [
          const Spacer(),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: C.bg(context),
              shape: BoxShape.circle,
              border: Border.all(color: C.line(context)),
            ),
            child: Icon(Icons.lock_outline, size: 32, color: C.muted(context)),
          ),
          const SizedBox(height: S.x5),
          Text('Đơn vị khác đã nhận', style: T.title(context)),
          const SizedBox(height: S.x2),
          Text('$takenBy nhận yêu cầu này lúc $takenAt,\ntrước bạn $secondsLate giây.',
              textAlign: TextAlign.center, style: T.small(context).copyWith(height: 1.7)),
          const SizedBox(height: S.x6),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              _kv(context, 'Yêu cầu', '#$requestId · $maskedPlate'),
              _kv(context, 'Khu vực', area),
              _kv(context, 'Trạng thái', 'Đang được xử lý', color: C.safe(context)),
            ]),
          ),
          const SizedBox(height: S.x4),
          const AlertBanner(
            level: Level.safe,
            icon: Icons.info_outline,
            text: 'Nếu đơn vị kia không cập nhật trong 15 phút, yêu cầu sẽ quay lại hàng chờ và bạn được thông báo.',
          ),
          const Spacer(),
          AppButton('Về danh sách yêu cầu', onTap: () => Navigator.pop(context)),
          const SizedBox(height: S.x3),
          AppButton('Xem yêu cầu khác gần đây · 6', tone: Tone.ghost, onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  Widget _kv(BuildContext c, String k, String v, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line(c)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: T.small(c)),
        Text(v, style: T.body(c, color).copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
