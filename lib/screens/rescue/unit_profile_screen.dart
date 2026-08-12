import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
            _ratingSummary(context, data),
            const SizedBox(height: S.x4),
            RowItem(
              icon: Icons.history,
              iconColor: C.brand(context),
              iconBg: C.brandBg(context),
              title: 'Lịch sử cứu hộ',
              sub: 'Xem các đơn đã hoàn thành',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RescueHistoryScreen())),
            ),
            const SizedBox(height: S.x4),
            _ratingList(context, FirebaseService.auth.currentUser!.uid),
            const SizedBox(height: 40),
            AppButton('Đăng xuất', icon: Icons.logout, tone: Tone.ghost, onTap: _logout),
          ],
        );
      }
    );
  }

  Widget _ratingSummary(BuildContext context, Map<String, dynamic> data) {
    final double avg = (data['ratingAvg'] as num?)?.toDouble() ?? 0.0;
    final int count = data['ratingCount'] ?? 0;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(avg.toStringAsFixed(1), style: GoogleFonts.jetBrainsMono(fontSize: 48, fontWeight: FontWeight.w900, color: C.ink(context))),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: List.generate(5, (i) => Icon(
              i < avg.floor() ? Icons.star_rounded : (i < avg ? Icons.star_half_rounded : Icons.star_outline_rounded),
              color: Colors.orange, size: 20,
            ))),
            const SizedBox(height: 4),
            Text('$count lượt đánh giá', style: T.caption(context).copyWith(fontWeight: FontWeight.bold)),
          ]),
        ]),
      ]),
    );
  }

  Widget _ratingList(BuildContext context, String rescuerId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text('ĐÁNH GIÁ GẦN ĐÂY', style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseService.db.collection('ratings')
              .where('rescuerId', isEqualTo: rescuerId)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Chưa có đánh giá nào.', style: T.caption(context))));

            return Column(children: docs.map((d) => _ratingItem(context, d.data() as Map<String, dynamic>)).toList());
          }
        ),
      ],
    );
  }

  Widget _ratingItem(BuildContext context, Map<String, dynamic> r) {
    final DateTime date = (r['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final double stars = (r['stars'] as num?)?.toDouble() ?? 0.0;
    final List<String> tags = List<String>.from(r['tags'] ?? []);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < stars ? Colors.orange : Colors.grey.shade200))),
          Text(DateFormat('dd/MM/yyyy').format(date), style: T.caption(context).copyWith(fontSize: 10)),
        ]),
        if (r['comment'] != null && r['comment'].toString().isNotEmpty) 
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(r['comment'], style: T.small(context))),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 4, children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
              child: Text(t, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
            )).toList()),
          ),
      ]),
    );
  }
}
