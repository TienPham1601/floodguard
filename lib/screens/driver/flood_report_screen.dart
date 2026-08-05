import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import '../../data/location_service.dart';

class FloodReportScreen extends StatefulWidget {
  const FloodReportScreen({super.key});
  @override
  State<FloodReportScreen> createState() => _FloodReportScreenState();
}

class _FloodReportScreenState extends State<FloodReportScreen> {
  double depth = 45;
  File? _image;
  String? _base64Thumb;
  final _picker = ImagePicker();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Color get _depthColor {
    if (depth >= 40) return C.danger(context);
    if (depth >= 25) return C.warn(context);
    return C.brand(context);
  }

  Future<void> _takePhoto() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 60,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _image = File(pickedFile.path);
          _base64Thumb = base64Encode(bytes);
        });
      }
    }
  }

  void _submit() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chụp ảnh hiện trường.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos == null) throw 'Không lấy được vị trí GPS.';

      await FirebaseService.addFloodReport(
        lat: pos.latitude,
        lng: pos.longitude,
        waterCm: depth.toInt(),
        photoBase64: _base64Thumb,
        description: _descCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn! Báo cáo đã được chia sẻ cho mọi người.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Báo cáo điểm ngập',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          const AlertBanner(
            level: Level.safe,
            icon: Icons.info_outline,
            text: 'Báo cáo của bạn sẽ giúp cảnh báo cộng đồng và tối ưu lộ trình cho người khác.',
          ),
          const SizedBox(height: S.x4),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _takePhoto,
                child: _photoSlot(context, 'Chụp ảnh', true, imageFile: _image),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _photoSlot(context, 'Ảnh xem trước', false, empty: _image == null, imageFile: _image)),
          ]),
          const SizedBox(height: S.x4),

          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Độ sâu ước tính', style: T.body(context).copyWith(fontWeight: FontWeight.w500)),
                Text('${depth.toStringAsFixed(0)} cm', style: T.mono(context, _depthColor)),
              ]),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(activeTrackColor: _depthColor, thumbColor: _depthColor),
                child: Slider(value: depth, min: 5, max: 60, onChanged: (v) => setState(() => depth = v)),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Ngang cổ chân', style: T.caption(context)),
                Text('Ngang nửa bánh xe', style: T.caption(context)),
              ]),
            ]),
          ),
          const SizedBox(height: S.x4),

          // Ô mô tả mới
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Mô tả tình trạng (tùy chọn)...', border: InputBorder.none, hintStyle: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: S.x5),

          _loading 
            ? const Center(child: CircularProgressIndicator())
            : AppButton('Gửi báo cáo cộng đồng', onTap: _submit),
        ],
      ),
    );
  }

  Widget _photoSlot(BuildContext c, String label, bool add, {bool empty = false, File? imageFile}) {
    return Container(
      height: 140,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: add ? C.brandBg(c) : const Color(0xFFDDE4EB),
        border: add ? Border.all(color: C.brand(c), width: 1.5) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: imageFile != null
          ? Image.file(imageFile, fit: BoxFit.cover)
          : (empty
              ? null
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (add) Icon(Icons.camera_alt_outlined, size: 24, color: C.brand(c)),
                  if (add) const SizedBox(height: 6),
                  Text(label, style: T.caption(c, add ? C.brand(c) : C.muted(c))),
                ])),
    );
  }
}
