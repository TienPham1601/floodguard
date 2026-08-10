import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import 'pair_device_screen.dart';

class AddVehicleScreen extends StatefulWidget {
  final bool isFirstTime;
  const AddVehicleScreen({super.key, this.isFirstTime = false});
  
  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _modelCtl = TextEditingController();
  final _plateCtl = TextEditingController();
  double _clearance = 150; // mm
  String _type = 'Sedan';
  bool _loading = false;

  final List<String> _types = ['Sedan', 'SUV', 'Hatchback', 'Bán tải', 'MPV', 'Crossover', 'Coupe', 'Van', 'Xe điện'];

  final Map<String, List<String>> _brandModels = {
    'Toyota': ['Vios', 'Camry', 'Corolla Cross', 'Innova', 'Fortuner', 'Raize', 'Yaris Cross', 'Land Cruiser'],
    'Honda': ['City', 'Civic', 'CR-V', 'HR-V', 'Accord'],
    'Hyundai': ['Accent', 'Elantra', 'Tucson', 'Santa Fe', 'Creta', 'Stargazer', 'Venue', 'Ioniq 5'],
    'Kia': ['Morning', 'Cerato', 'K3', 'Seltos', 'Sonet', 'Carnival', 'Carens', 'Sportage', 'EV6'],
    'Mazda': ['2', '3', '6', 'CX-5', 'CX-8', 'CX-3', 'CX-30'],
    'VinFast': ['VF3', 'VF5', 'VF6', 'VF7', 'VF8', 'VF9', 'Lux A2.0', 'Lux SA2.0', 'Fadil'],
    'Ford': ['Ranger', 'Everest', 'Territory', 'Explorer'],
    'Mitsubishi': ['Xpander', 'Attrage', 'Outlander', 'Pajero Sport'],
    'Mercedes-Benz': ['C-Class', 'E-Class', 'S-Class', 'GLC', 'GLE', 'GLS'],
    'BMW': ['3 Series', '5 Series', '7 Series', 'X3', 'X5', 'X7'],
  };

  late List<String> _suggestions;

  @override
  void initState() {
    super.initState();
    _suggestions = [];
    _brandModels.forEach((brand, models) {
      for (var m in models) {
        _suggestions.add('$brand $m');
      }
    });
  }

  String _formatPlate(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\.\-\s]'), '').toUpperCase();
    if (clean.length < 4) return clean;
    final match = RegExp(r'^(\d{2})([A-Z]{1,2})(\d{4,5})$').firstMatch(clean);
    if (match != null) {
      final tinh = match.group(1);
      final seri = match.group(2);
      final so = match.group(3)!;
      String soFormated = so;
      if (so.length == 5) soFormated = '${so.substring(0, 3)}.${so.substring(3)}';
      return '$tinh$seri-$soFormated';
    }
    return clean;
  }

  bool _isValidPlate(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\.\-\s]'), '').toUpperCase();
    return RegExp(r'^\d{2}[A-Z]{1,2}\d{4,5}$').hasMatch(clean);
  }

  void _save() async {
    final model = _modelCtl.text.trim();
    final rawPlate = _plateCtl.text.trim();

    if (model.isEmpty || rawPlate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin.')));
      return;
    }

    if (!_isValidPlate(rawPlate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biển số không đúng định dạng. Ví dụ: 51A-123.45')));
      return;
    }

    final formattedPlate = _formatPlate(rawPlate);

    setState(() => _loading = true);
    try {
      dev.log('ADD_VEHICLE: Starting save process...');
      final docRef = await FirebaseService.db.collection('vehicles').add({
        'ownerId': FirebaseService.auth.currentUser!.uid,
        'model': model,
        'plate': formattedPlate,
        'type': _type,
        'waterCm': 0,
        'tempC': 25,
        'warnAt': _clearance / 10,
        'dangerAt': (_clearance / 10) + 15,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      dev.log('ADD_VEHICLE: Saved to Firestore with ID: ${docRef.id}');

      // LỖI 1: Tự động chọn xe vừa tạo làm xe hiện tại
      await FirebaseService.selectVehicle(docRef.id);
      dev.log('ADD_VEHICLE: Selected new vehicle as current. ID: ${docRef.id}');

      if (mounted) {
        if (widget.isFirstTime) {
          dev.log('ADD_VEHICLE: Redirecting to Onboarding (First Time)');
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PairDeviceScreen()));
        } else {
          dev.log('ADD_VEHICLE: Popping back to previous screen (Success)');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      dev.log('ADD_VEHICLE: Critical Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi thêm xe: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Thêm xe',
          left: widget.isFirstTime ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.isFirstTime) ...[
            Text('Chào mừng bạn!', style: T.h2(context).copyWith(fontSize: 24)),
            const SizedBox(height: 6),
            Text('Hãy nhập thông tin chiếc xe bạn muốn bảo vệ.', style: T.small(context)),
            const SizedBox(height: 32),
          ],

          _label('Dòng xe'),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
              return _suggestions.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) => _modelCtl.text = selection,
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              if (_modelCtl.text.isEmpty && controller.text.isNotEmpty) _modelCtl.text = controller.text;
              controller.addListener(() => _modelCtl.text = controller.text);
              return _inputField(context, controller: controller, focusNode: focusNode, hint: 'Ví dụ: Toyota Vios');
            },
          ),
          const SizedBox(height: 20),

          _label('Loại xe'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: C.surface(context), border: Border.all(color: C.line(context)), borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _type,
                isExpanded: true,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: T.body(context)))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _label('Biển số'),
          _inputField(context, controller: _plateCtl, hint: 'Ví dụ: 51A-123.45'),
          const SizedBox(height: 20),

          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Khoảng sáng gầm', style: T.body(context).copyWith(fontWeight: FontWeight.bold)),
                Text('${_clearance.toStringAsFixed(0)} mm', style: T.mono(context, C.brand(context))),
              ]),
              Slider(
                value: _clearance, min: 100, max: 300, 
                activeColor: C.brand(context), 
                onChanged: (v) => setState(() => _clearance = v)
              ),
              Text('Dùng để tính toán ngưỡng cảnh báo ngập chính xác cho xe.', style: T.caption(context)),
            ]),
          ),
          const SizedBox(height: 40),

          _loading 
            ? const Center(child: CircularProgressIndicator())
            : AppButton(widget.isFirstTime ? 'Tiếp tục' : 'Lưu thông tin', onTap: _save),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(t, style: T.small(context).copyWith(fontWeight: FontWeight.bold)));

  Widget _inputField(BuildContext c, {required TextEditingController controller, FocusNode? focusNode, String? hint}) {
    return Container(
      height: 52, padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: C.surface(c), border: Border.all(color: C.line(c)), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller, focusNode: focusNode,
        textCapitalization: TextCapitalization.characters,
        style: T.body(c),
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: T.small(c)),
      ),
    );
  }
}
