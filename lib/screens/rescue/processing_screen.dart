import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/rescue_data.dart';
import '../../utils.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final req = rescue.active;
    final arrived = req?.status == ReqStatus.arrived;

    if (req == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, size: 48, color: C.muted(context)),
            const SizedBox(height: 16),
            Text('Chưa nhận yêu cầu nào', style: T.title(context)),
            const SizedBox(height: 6),
            Text('Nhận một yêu cầu ở tab Yêu cầu để bắt đầu xử lý.',
                textAlign: TextAlign.center, style: T.small(context)),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(S.x4),
      children: [
        Container(
          decoration: BoxDecoration(
            color: C.surface(context),
            border: Border.all(color: C.brand(context), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(S.x4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(req.plateFull, style: T.title(context)),
                  const SizedBox(height: 2),
                  Text('${req.ownerName} · ${req.model}', style: T.small(context)),
                ]),
              ),
              StatusTag('#${req.id}', fg: C.brand(context), bg: C.brandBg(context)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: C.brandBg(context), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _stat(context, '1,1', 'km còn lại'),
                _stat(context, '4', 'phút nữa tới', right: true),
              ]),
            ),
            const SizedBox(height: 16),
            _step(context, done: true, current: false, title: 'Đã nhận yêu cầu', sub: '15:43', last: false),
            _step(context, done: arrived, current: !arrived, title: 'Đang di chuyển',
                sub: 'Từ 15:45 · đang chia sẻ vị trí cho chủ xe', last: false, n: '2'),
            _step(context, done: false, current: arrived, title: 'Đã tới hiện trường',
                sub: arrived ? 'Bấm Hoàn tất khi xong việc' : '', last: false, n: '3'),
            _step(context, done: false, current: false, title: 'Hoàn tất', sub: '', last: true, n: '4'),
          ]),
        ),
        const SizedBox(height: S.x4),
        Row(children: [
          Expanded(
            child: AppButton('Gọi chủ xe', icon: Icons.phone, tone: Tone.ghost,
                onTap: () => callPhone(context, req.ownerPhone)),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: arrived
                ? AppButton('Hoàn tất', icon: Icons.check, tone: Tone.brand,
                    onTap: () => _confirmFinish(context, req.id))
                : AppButton('Đã tới nơi', tone: Tone.brand, onTap: () {
                    rescue.markArrived(req.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật: có mặt tại hiện trường')),
                    );
                  }),
          ),
        ]),
        const SizedBox(height: S.x3),
        AppButton('Dẫn đường trên bản đồ', icon: Icons.navigation, tone: Tone.soft, onTap: () {
          navigateTo.value = req;
        }),
        const SizedBox(height: S.x3),
        AppButton('Huỷ nhận yêu cầu', tone: Tone.ghost, onTap: () => rescue.cancel(req.id)),
      ],
    );
  }

  void _confirmFinish(BuildContext c, String id) {
    showDialog(
      context: c,
      builder: (ctx) => AlertDialog(
        title: Text('Hoàn tất yêu cầu?', style: T.title(ctx)),
        content: Text('Yêu cầu sẽ chuyển vào lịch sử. Thông tin liên hệ chủ xe bị thu hồi sau 24 giờ.',
            style: T.body(ctx)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Quay lại')),
          FilledButton(
            onPressed: () {
              rescue.finish(id);
              Navigator.pop(ctx);
            },
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext c, String value, String label, {bool right = false}) {
    return Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      Text(value, style: T.mono(c, C.brand(c))),
      Text(label, style: T.caption(c, C.brand(c))),
    ]);
  }

  Widget _step(BuildContext c, {required bool done, required bool current, required String title, required String sub, required bool last, String? n}) {
    final circleColor = done ? C.safe(c) : (current ? C.brand(c) : C.bg(c));
    final textColor = done || current ? C.ink(c) : C.muted(c);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              border: (!done && !current) ? Border.all(color: C.line(c)) : null,
            ),
            child: done
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Center(child: Text(n ?? '', style: TextStyle(color: current ? Colors.white : C.muted(c), fontSize: 11, fontWeight: FontWeight.w700))),
          ),
          if (!last) Expanded(child: Container(width: 2, color: done ? C.safe(c) : C.line(c))),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.body(c, current ? C.brand(c) : textColor).copyWith(fontWeight: FontWeight.w600)),
              if (sub.isNotEmpty) Text(sub, style: T.small(c)),
            ]),
          ),
        ),
      ]),
    );
  }
}
