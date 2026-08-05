import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';

class InsuranceScreen extends StatelessWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Báo cáo bảo hiểm',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SỰ CỐ', style: T.caption(context).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Ngập 38cm · 25/07 15:38', style: T.body(context).copyWith(fontWeight: FontWeight.w500)),
                Icon(Icons.keyboard_arrow_down, size: 18, color: C.muted(context)),
              ]),
              Text('Nguyễn Hữu Cảnh, Bình Thạnh', style: T.small(context)),
            ]),
          ),
          const SizedBox(height: S.x4),
          Text('ẢNH HIỆN TRƯỜNG', style: T.caption(context).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _photo(context, 'Ảnh 1', false)),
            const SizedBox(width: 10),
            Expanded(child: _photo(context, 'Ảnh 2', false)),
            const SizedBox(width: 10),
            Expanded(child: _photo(context, 'Thêm', true)),
          ]),
          const SizedBox(height: S.x4),
          Text('MÔ TẢ', style: T.caption(context).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: 82,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.surface(context),
              border: Border.all(color: C.brand(context), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Xe đỗ tại chỗ, nước dâng bất ngờ. Hệ thống đã tự ngắt nguồn nhưng nước vào khoang nội thất.',
                style: T.small(context, C.ink(context)).copyWith(height: 1.5)),
          ),
          const SizedBox(height: S.x4),
          AppCard(
            color: C.brandBg(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tự động đính kèm', style: T.body(context, C.brand(context)).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _attach(context, 'Trích xuất nhật ký 25/07 (14 sự kiện)'),
              _attach(context, 'Toạ độ GPS thời điểm sự cố'),
              _attach(context, 'Biểu đồ mực nước 6 giờ'),
              _attach(context, 'Thông tin xe và biển số'),
            ]),
          ),
          const SizedBox(height: S.x4),
          Text('GỬI TỚI', style: T.caption(context).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: C.surface(context),
              border: Border.all(color: C.brand(context), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.mail_outline, size: 18, color: C.muted(context)),
              const SizedBox(width: 10),
              Text('boithuong@pjico.com.vn', style: T.body(context).copyWith(fontSize: 14)),
            ]),
          ),
          const SizedBox(height: S.x4),
          AppButton('Gửi báo cáo', onTap: () {}),
        ],
      ),
    );
  }

  Widget _photo(BuildContext c, String label, bool add) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: add ? C.brandBg(c) : const Color(0xFFDDE4EB),
        border: add ? Border.all(color: C.brand(c), width: 1.5) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (add) Icon(Icons.add_a_photo_outlined, size: 20, color: C.brand(c)),
        if (add) const SizedBox(height: 4),
        Text(label, style: T.caption(c, add ? C.brand(c) : C.muted(c))),
      ]),
    );
  }

  Widget _attach(BuildContext c, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check, size: 15, color: C.brand(c)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: T.caption(c, C.brand(c)).copyWith(height: 1.5))),
      ]),
    );
  }
}
