import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import 'members_screen.dart';
import 'insurance_report_screen.dart';
import 'incident_logs_screen.dart';
// unused import removed: import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _oldPassCtl = TextEditingController();
  final _newPassCtl = TextEditingController();
  final _confirmPassCtl = TextEditingController();
  bool _loadingPass = false;

  void _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 200, maxHeight: 200, imageQuality: 60);
    if (img != null) {
      final bytes = await img.readAsBytes();
      final base64 = base64Encode(bytes);
      await FirebaseFirestore.instance.collection('users').doc(FirebaseService.auth.currentUser!.uid).update({'avatar': base64});
    }
  }

  void _showQR() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Chia sẻ xe của bạn', style: T.title(ctx)),
          const SizedBox(height: 12),
          Text('Người thân quét mã này để cùng quản lý xe.', style: T.small(ctx), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          QrImageView(data: FirebaseService.auth.currentUser!.uid, size: 200, foregroundColor: C.brand(ctx)),
          const SizedBox(height: 24),
          AppButton('Đóng', tone: Tone.ghost, onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    );
  }

  void _scanQR() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.8,
        child: MobileScanner(
          onDetect: (capture) async {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final ownerId = barcodes.first.rawValue;
              if (ownerId != null) {
                // Logic: thêm uid hiện tại vào danh sách chia sẻ của ownerId
                // TODO: Triển khai logic join group cụ thể trong Firestore
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu kết nối.')));
              }
            }
          },
        ),
      ),
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn thoát khỏi ứng dụng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      
      try {
        await FirebaseService.logout();
        // Không gọi Navigator.pushAndRemoveUntil ở đây vì main.dart sẽ tự động đổi home sang LoginScreen
        // Chúng ta chỉ cần đóng dialog loading (nếu còn mounted)
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  void _showChangePassDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Đổi mật khẩu', style: T.title(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(ctx, controller: _oldPassCtl, hint: 'Mật khẩu hiện tại', obscure: true),
              const SizedBox(height: 10),
              _field(ctx, controller: _newPassCtl, hint: 'Mật khẩu mới', obscure: true),
              const SizedBox(height: 10),
              _field(ctx, controller: _confirmPassCtl, hint: 'Xác nhận mật khẩu mới', obscure: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            _loadingPass 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : FilledButton(
                  onPressed: () async {
                    if (_newPassCtl.text != _confirmPassCtl.text) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Xác nhận mật khẩu không khớp.')));
                      return;
                    }
                    setDialogState(() => _loadingPass = true);
                    try {
                      await FirebaseService.changePassword(_oldPassCtl.text, _newPassCtl.text);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công.')));
                      }
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                    } finally {
                      if (ctx.mounted) setDialogState(() => _loadingPass = false);
                    }
                  },
                  child: const Text('Cập nhật'),
                ),
          ],
        ),
      ),
    );
  }

  Widget _field(BuildContext c, {required TextEditingController controller, String? hint, bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: T.small(c),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.streamUserProfile(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['name'] ?? 'Đang tải...';
        final phone = data?['phone'] ?? '...';
        final avatarBase64 = data?['avatar'];

        return ListView(
          padding: const EdgeInsets.all(S.x4),
          children: [
            AppCard(
              child: Row(children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: C.brandBg(context),
                      backgroundImage: avatarBase64 != null ? MemoryImage(base64Decode(avatarBase64)) : null,
                      child: avatarBase64 == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', 
                          style: T.h2(context).copyWith(color: C.brand(context))) : null,
                    ),
                    Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, size: 12, color: Colors.white))),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: T.title(context).copyWith(fontSize: 20)),
                    Text(phone, style: T.body(context, C.muted(context))),
                  ]),
                ),
              ]),
            ).animate().fade().slideX(begin: -0.1),
            const SizedBox(height: S.x4),

            _sectionLabel('QUẢN LÝ XE'),
            _item(context, Icons.directions_car, 'Phương tiện của tôi', 'Danh sách và thông tin xe', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembersScreen()))),
            _item(context, Icons.qr_code, 'Mã QR chia sẻ', 'Để người thân cùng theo dõi xe', onTap: _showQR),
            _item(context, Icons.qr_code_scanner, 'Quét mã người khác', 'Để theo dõi xe được chia sẻ', onTap: _scanQR),
            
            const SizedBox(height: S.x4),
            _sectionLabel('TIỆN ÍCH & BẢO HIỂM'),
            _item(context, Icons.verified_user_outlined, 'Báo cáo bảo hiểm', 'Tạo hồ sơ bồi thường sự cố', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsuranceReportScreen()))),
            _item(context, Icons.history, 'Nhật ký sự cố', 'Lịch sử mực nước và cảnh báo', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentLogsScreen()))),
            
            const SizedBox(height: S.x4),
            _sectionLabel('TÀI KHOẢN'),
            _item(context, Icons.lock_outline, 'Đổi mật khẩu', 'Bảo mật tài khoản', onTap: _showChangePassDialog),
            
            const SizedBox(height: S.x6),
            AppButton('Đăng xuất', tone: Tone.ghost, onTap: _logout).animate().fade(delay: const Duration(milliseconds: 200)),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String t) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8), child: Text(t, style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)));

  Widget _item(BuildContext c, IconData icon, String title, String sub, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x3),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: C.brand(c)),
        title: Text(title, style: T.body(c).copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: T.small(c)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: C.line(c))),
      ),
    ).animate().fade().slideY(begin: 0.1);
  }
}
