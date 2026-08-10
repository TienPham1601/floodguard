import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../ui.dart';
import 'history_screen.dart';
import '../../data/firebase_service.dart';
// Removed unused import: ../auth/login_screen.dart

class UnitProfileScreen extends StatefulWidget {
  const UnitProfileScreen({super.key});

  @override
  State<UnitProfileScreen> createState() => _UnitProfileScreenState();
}

class _UnitProfileScreenState extends State<UnitProfileScreen> {
  bool receiving = true;

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
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.streamUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data?.data();
        if (data == null) return const Center(child: Text('Lỗi tải dữ liệu.'));

        double radius = (data['serviceRadius'] as num?)?.toDouble() ?? 8.0;

        return ListView(
          padding: const EdgeInsets.all(S.x4),
          children: [
            AppCard(
              child: Row(children: [
                CircleAvatar(radius: 26, backgroundColor: C.safeBg(context), child: Text(data['garageName']?[0] ?? 'G', style: T.label(context, C.safe(context)))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['garageName'] ?? 'Gara cứu hộ', style: T.title(context)),
                    Row(children: [
                      Text('Thợ: ', style: T.small(context)),
                      Text(data['name'] ?? '', style: T.small(context).copyWith(fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: S.x4),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Đang nhận yêu cầu', style: T.title(context).copyWith(fontSize: 15)),
                    const SizedBox(height: 3),
                    Text('Tắt để không nhận thêm đơn mới', style: T.caption(context)),
                  ]),
                ),
                Switch(value: receiving, onChanged: (v) => setState(() => receiving = v)),
              ]),
            ),
            const SizedBox(height: S.x4),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Bán kính phục vụ', style: T.body(context).copyWith(fontWeight: FontWeight.w500)),
                  Text('${radius.toStringAsFixed(0)} km', style: T.mono(context, C.brand(context)).copyWith(fontSize: 16)),
                ]),
                Slider(
                  value: radius, min: 2, max: 50, 
                  activeColor: C.brand(context), 
                  onChanged: (v) => FirebaseService.updateServiceRadius(v.toInt())
                ),
                Text('Chỉ nhận yêu cầu cứu hộ trong phạm vi này.', style: T.caption(context)),
              ]),
            ),
            const SizedBox(height: S.x4),
            RowItem(
              icon: Icons.history,
              iconColor: C.brand(context),
              iconBg: C.brandBg(context),
              title: 'Lịch sử cứu hộ',
              sub: 'Xem các đơn đã hoàn thành',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RescueHistoryScreen())),
            ),
            const SizedBox(height: 40),
            AppButton('Đăng xuất', icon: Icons.logout, tone: Tone.ghost, onTap: _logout),
          ],
        );
      }
    );
  }
}
