import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/rescue_data.dart';
import 'request_detail_screen.dart';
import 'already_taken_screen.dart';

class RequestListScreen extends StatelessWidget {
  const RequestListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final waiting = rescue.waitingList;

    return ListView(
      padding: const EdgeInsets.all(S.x4),
      children: [
        if (waiting.isEmpty) ...[
          const SizedBox(height: 60),
          Icon(Icons.inbox_outlined, size: 48, color: C.muted(context)),
          const SizedBox(height: 16),
          Center(child: Text('Không còn yêu cầu chờ', style: T.title(context))),
          const SizedBox(height: 6),
          Center(
            child: Text('Bạn đã xử lý hoặc bỏ qua tất cả.',
                textAlign: TextAlign.center, style: T.small(context)),
          ),
          const SizedBox(height: S.x5),
          AppButton('Tải lại danh sách', tone: Tone.ghost, onTap: () {
            for (final r in rescue.requests) {
              if (r.status == ReqStatus.dismissed) r.status = ReqStatus.waiting;
            }
            rescue.notify();
          }),
        ] else ...[
        const AlertBanner(
          level: Level.danger,
          text: 'Điểm nóng: 4 xe báo SOS quanh Nguyễn Hữu Cảnh trong 20 phút.',
        ),
        const SizedBox(height: S.x4),
        for (int i = 0; i < waiting.length; i++) ...[
          _RequestCard(req: waiting[i], highlight: i == 0),
          const SizedBox(height: S.x3),
        ],
        const SizedBox(height: S.x1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: C.bg(context), borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline, size: 17, color: C.muted(context)),
            const SizedBox(width: 9),
            Expanded(
              child: Text('Biển số đầy đủ, tên và số điện thoại chủ xe chỉ hiện sau khi bạn nhận yêu cầu.',
                  style: T.caption(context)),
            ),
          ]),
        ),
        ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final SosRequest req;
  final bool highlight;
  const _RequestCard({required this.req, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final badge = req.personInside
        ? StatusTag('CÓ NGƯỜI TRONG XE', fg: C.danger(context), bg: C.dangerBg(context))
        : (req.minutesAgo <= 2
            ? StatusTag('MỚI · ${req.minutesAgo} phút', fg: C.danger(context), bg: C.dangerBg(context))
            : StatusTag('CHỜ · ${req.minutesAgo} phút', fg: C.warn(context), bg: C.warnBg(context)));

    return Container(
      decoration: BoxDecoration(
        color: C.surface(context),
        border: Border.all(color: highlight ? C.danger(context) : C.line(context), width: highlight ? 1.5 : 1),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(S.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          badge,
          Text(req.distanceLabel, style: T.small(context)),
        ]),
        const SizedBox(height: 10),
        Text('${req.plate} · ${req.vehicleType}', style: T.title(context)),
        const SizedBox(height: 5),
        Text.rich(TextSpan(
          style: T.small(context).copyWith(height: 1.6),
          children: [
            TextSpan(text: '${req.areaName}\n'),
            TextSpan(text: 'Ngập ${req.waterCm}cm · '),
            if (req.personInside)
              TextSpan(text: '1 người còn trong xe', style: TextStyle(color: C.danger(context), fontWeight: FontWeight.w600))
            else
              TextSpan(text: req.powerCut ? 'đã ngắt nguồn' : 'động cơ còn hoạt động'),
          ],
        )),
        if (highlight) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: AppButton('Bỏ qua', tone: Tone.ghost, height: 46,
                  onTap: () => rescue.dismiss(req.id)),
            ),
            const SizedBox(width: S.x3),
            Expanded(
              child: AppButton('Xem chi tiết', height: 46, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(id: req.id)));
              }),
            ),
          ]),
        ] else ...[
          const SizedBox(height: 10),
          AppButton('Xem chi tiết', tone: Tone.ghost, height: 44, onTap: () {
            // Yêu cầu chờ lâu nhất mô phỏng tình huống đơn vị khác đã nhận trước.
            final screen = req.minutesAgo >= 10
                ? AlreadyTakenScreen(requestId: req.id, maskedPlate: req.plate, area: req.areaName)
                : RequestDetailScreen(id: req.id);
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
          }),
        ],
      ]),
    );
  }
}
