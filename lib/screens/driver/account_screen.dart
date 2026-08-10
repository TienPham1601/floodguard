import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/app_settings.dart';

/// Thông tin tài khoản cá nhân.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Thông tin cá nhân',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          Center(
            child: Stack(children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: C.brandBg(context),
                child: Text('PT', style: T.h2(context).copyWith(color: C.brand(context))),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: C.brand(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: C.bg(context), width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                ),
              ),
            ]),
          ),
          const SizedBox(height: S.x4),
          Center(child: Text('Phạm Thu', style: T.title(context))),
          const SizedBox(height: 4),
          Center(child: Text('Tài khoản tài xế · tham gia 12/05/2026', style: T.small(context))),
          const SizedBox(height: S.x5),

          _label(context, 'THÔNG TIN LIÊN HỆ'),
          _group(context, [
            _row(context, Icons.person_outline, 'Họ và tên', 'Phạm Thu', editable: true),
            _row(context, Icons.phone_outlined, 'Số điện thoại', '0912 448 209', mono: true),
            _row(context, Icons.mail_outline, 'Email', 'thu.pham@gmail.com', editable: true),
            _row(context, Icons.location_on_outlined, 'Địa chỉ', 'Bình Thạnh, TP.HCM', editable: true, last: true),
          ]),
          const SizedBox(height: S.x4),

          _label(context, 'BẢO MẬT'),
          _group(context, [
            _row(context, Icons.lock_outline, 'Đổi mật khẩu', '', editable: true),
            _row(context, Icons.phonelink_lock_outlined, 'Xác thực hai bước', 'Chưa bật', editable: true, last: true),
          ]),
          const SizedBox(height: S.x4),

          _label(context, 'THỐNG KÊ'),
          Row(children: [
            Expanded(child: _stat(context, '2', 'xe đang quản lý')),
            const SizedBox(width: S.x3),
            Expanded(child: _stat(context, '14', 'sự kiện an toàn')),
            const SizedBox(width: S.x3),
            Expanded(child: _stat(context, '3', 'báo cáo ngập')),
          ]),
          const SizedBox(height: S.x5),

          AppButton('Đăng xuất', icon: Icons.logout, tone: Tone.ghost,
              onTap: () {
                appStage.value = AppStage.login;
                Navigator.pop(context);
              }),
          const SizedBox(height: S.x3),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text('Xoá tài khoản', style: T.small(context, C.danger(context))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t, style: T.caption(c).copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _group(BuildContext c, List<Widget> items) => Container(
        decoration: BoxDecoration(
          color: C.surface(c),
          border: Border.all(color: C.line(c)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: items),
      );

  Widget _row(BuildContext c, IconData icon, String label, String value,
      {bool editable = false, bool mono = false, bool last = false}) {
    return InkWell(
      onTap: editable ? () {} : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: C.line(c))),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: C.muted(c)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: T.body(c))),
          if (value.isNotEmpty)
            Text(value, style: mono ? T.monoSm(c, C.ink(c)) : T.small(c)),
          if (editable) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: C.muted(c)),
          ],
        ]),
      ),
    );
  }

  Widget _stat(BuildContext c, String value, String label) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(children: [
          Text(value, style: T.mono(c, C.brand(c)).copyWith(fontSize: 22)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: T.caption(c)),
        ]),
      );
}
