import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/vehicle_state.dart';

/// Chia sẻ xe: chủ xe hiện mã QR hoặc đọc mã chữ, người kia quét bằng
/// camera điện thoại rồi nhập mã vào tab thứ hai.
class InviteQrScreen extends StatefulWidget {
  const InviteQrScreen({super.key});
  @override
  State<InviteQrScreen> createState() => _InviteQrScreenState();
}

class _InviteQrScreenState extends State<InviteQrScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _codeCtl = TextEditingController();

  /// Mã mời gắn với biển số. Bản thật sẽ là token ký từ server, hết hạn sau 24 giờ.
  String get _inviteCode => 'NCC-${vehicle.plate.replaceAll(RegExp(r'[^0-9A-Z]'), '')}-A3F2';

  bool get _codeValid => _codeCtl.text.trim().toUpperCase() == _inviteCode;

  @override
  void dispose() {
    _tab.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: AppBar(
        backgroundColor: C.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Chia sẻ xe', style: T.title(context)),
        shape: Border(bottom: BorderSide(color: C.line(context))),
        bottom: TabBar(
          controller: _tab,
          labelColor: C.brand(context),
          unselectedLabelColor: C.muted(context),
          indicatorColor: C.brand(context),
          labelStyle: T.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [Tab(text: 'Mã của tôi'), Tab(text: 'Nhập mã')],
        ),
      ),
      child: TabBarView(controller: _tab, children: [
        _myCode(context),
        _enterCode(context),
      ]),
    );
  }

  // ---------- Tab 1: hiện mã QR ----------
  Widget _myCode(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(S.x4),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.line(context)),
            ),
            child: QrImageView(
              data: _inviteCode,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: S.x4),
        Center(child: Text(vehicle.plate, style: T.mono(context).copyWith(fontSize: 20))),
        const SizedBox(height: 4),
        Center(child: Text('${vehicle.model} · mã có hiệu lực 24 giờ', style: T.small(context))),
        const SizedBox(height: S.x4),

        // Mã dạng chữ để đọc qua điện thoại khi không tiện quét
        AppCard(
          color: C.brandBg(context),
          child: Column(children: [
            Text('MÃ DẠNG CHỮ', style: T.caption(context, C.brand(context)).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(_inviteCode,
                style: T.mono(context, C.brand(context)).copyWith(fontSize: 20, letterSpacing: 2)),
          ]),
        ),
        const SizedBox(height: S.x3),
        AppButton('Sao chép mã', icon: Icons.copy, tone: Tone.soft, onTap: () {
          Clipboard.setData(ClipboardData(text: _inviteCode));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã sao chép mã mời'), duration: Duration(seconds: 2)),
          );
        }),
        const SizedBox(height: S.x4),

        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cách mời', style: T.title(context).copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            _step(context, '1', 'Người được mời cài NewCarCare và đăng ký tài khoản'),
            _step(context, '2', 'Họ quét mã QR này bằng camera điện thoại, hoặc bạn đọc mã chữ cho họ'),
            _step(context, '3', 'Họ vào Chia sẻ xe, tab Nhập mã, gõ mã vào là xong'),
          ]),
        ),
        const SizedBox(height: S.x3),
        const AlertBanner(
          text: 'Thành viên xem được dữ liệu và đóng cổ hút. Chỉ chủ xe mở lại được khi đang nguy hiểm.',
        ),
      ],
    );
  }

  // ---------- Tab 2: nhập mã để tham gia ----------
  Widget _enterCode(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(S.x4),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: C.brandBg(context), shape: BoxShape.circle),
            child: Icon(Icons.key_outlined, size: 32, color: C.brand(context)),
          ),
        ),
        const SizedBox(height: S.x4),
        Center(child: Text('Nhập mã mời', style: T.title(context))),
        const SizedBox(height: 6),
        Center(
          child: Text('Quét mã QR của chủ xe bằng camera điện thoại,\nhoặc gõ mã chữ họ đọc cho bạn',
              textAlign: TextAlign.center, style: T.small(context).copyWith(height: 1.6)),
        ),
        const SizedBox(height: S.x5),

        Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.surface(context),
            border: Border.all(
                color: _codeCtl.text.isEmpty
                    ? C.line(context)
                    : (_codeValid ? C.safe(context) : C.danger(context)),
                width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _codeCtl,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            style: T.mono(context, C.ink(context)).copyWith(fontSize: 19, letterSpacing: 2),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: 'NCC-51A12345-XXXX',
              hintStyle: T.small(context),
            ),
          ),
        ),
        if (_codeCtl.text.isNotEmpty && !_codeValid) ...[
          const SizedBox(height: 8),
          Center(child: Text('Mã không đúng hoặc đã hết hạn', style: T.caption(context, C.danger(context)))),
        ],
        const SizedBox(height: S.x5),

        AppButton('Tham gia xe',
            tone: _codeValid ? Tone.brand : Tone.ghost,
            onTap: _codeValid ? () => _join(context) : null),
        const SizedBox(height: S.x4),
        const AlertBanner(
          level: Level.safe,
          icon: Icons.info_outline,
          text: 'Bản mô phỏng: dùng đúng mã ở tab Mã của tôi để thử luồng tham gia.',
        ),
      ],
    );
  }

  void _join(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tham gia xe ${vehicle.plate}?', style: T.title(ctx)),
        content: Text('Bạn sẽ xem được dữ liệu và điều khiển bảo vệ xe này.', style: T.body(ctx)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã tham gia xe ${vehicle.plate}')),
              );
            },
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
  }

  Widget _step(BuildContext c, String n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.brandBg(c), borderRadius: BorderRadius.circular(7)),
          child: Text(n, style: T.caption(c, C.brand(c)).copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: T.small(c, C.ink(c)).copyWith(height: 1.5))),
      ]),
    );
  }
}
