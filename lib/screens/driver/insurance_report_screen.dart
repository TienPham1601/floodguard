import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/material.dart';
// Removed unused imports
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import '../../data/location_service.dart';
import '../../data/places.dart';

class InsuranceReportScreen extends StatefulWidget {
  final SOSRequest? initialSOS;
  const InsuranceReportScreen({super.key, this.initialSOS});

  @override
  State<InsuranceReportScreen> createState() => _InsuranceReportScreenState();
}

class _InsuranceReportScreenState extends State<InsuranceReportScreen> {
  int _step = 0; 
  String _address = 'Chưa xác định';
  LatLng? _coords;
  final List<XFile> _images = [];
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  
  bool _loading = false;
  List<SOSRequest> _recentSOS = [];
  
  // Thông tin xe được chọn từ SOS (nếu dùng nguồn SOS)
  String? _manualVehiclePlate;
  String? _manualVehicleModel;
  
  DateTime _targetTime = DateTime.now();
  String _sourceName = 'Vị trí hiện tại';
  String? _selectedSOSId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Timer? _searchDebounce;

  Future<void> _initData() async {
    try {
      final prof = await FirebaseService.getUserProfile();
      if (mounted) _emailCtrl.text = prof?['insuranceEmail'] ?? '';
      
      final sosList = await FirebaseService.getRecentSOS(limit: 5);
      if (mounted) {
        setState(() {
          _recentSOS = sosList;
        });
        
        if (widget.initialSOS != null) {
          _useSOSLocation(widget.initialSOS!);
        } else if (sosList.isNotEmpty) {
          _useSOSLocation(sosList.first);
        }
      }
    } catch (e) {
      dev.log('INSURANCE_INIT_ERROR: $e');
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  void _useSOSLocation(SOSRequest sos) async {
    setState(() {
       _selectedSOSId = sos.id;
    });
    final addr = await SearchService.reverseGeocode(sos.latitude, sos.longitude);
    if (mounted) {
      setState(() {
        _address = addr;
        _coords = LatLng(sos.latitude, sos.longitude);
        _manualVehiclePlate = sos.vehiclePlate;
        _manualVehicleModel = sos.vehicleModel;
        _targetTime = sos.createdAt;
        _sourceName = 'SOS Gần đây';
      });
    }
  }

  void _useCurrentLocation() async {
    setState(() {
      _loading = true;
      _address = 'Đang lấy vị trí...'; // HIỂN THỊ TRẠNG THÁI CHỜ
      _selectedSOSId = null;
      _manualVehicleModel = null;
      _manualVehiclePlate = null;
    });
    
    try {
      dev.log('INSURANCE_GPS: Requesting current position...');
      final pos = await LocationService.getCurrentLocation();
      
      if (pos != null) {
        dev.log('INSURANCE_GPS: Got coordinates: ${pos.latitude}, ${pos.longitude}');
        final addr = await SearchService.reverseGeocode(pos.latitude, pos.longitude);
        dev.log('INSURANCE_GPS: Geocode result: $addr');
        
        if (mounted) {
          setState(() {
            _address = addr;
            _coords = pos;
            _targetTime = DateTime.now();
            _sourceName = 'Vị trí hiện tại';
            _loading = false;
          });
        }
      } else {
        dev.log('INSURANCE_GPS: Position returned null');
        if (mounted) {
          setState(() {
            _address = 'Không thể lấy GPS. Vui lòng thử lại.';
            _loading = false;
          });
        }
      }
    } catch (e) {
      dev.log('INSURANCE_GPS_ERROR: $e');
      if (mounted) {
        setState(() {
          _address = 'Lỗi GPS: $e';
          _loading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    if (val.isEmpty) {
      setState(() {});
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      final results = await SearchService.search(val);
      if (mounted) setState(() { _searchResults = results; });
    });
  }

  List<Place> _searchResults = [];

  void _selectPlace(Place p) async {
    setState(() {
      _address = p.address;
      _coords = p.pos;
      _selectedSOSId = null;
      _manualVehicleModel = null;
      _manualVehiclePlate = null;
      _targetTime = DateTime.now();
      _sourceName = 'Tự nhập vị trí';
      _searchResults = [];
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70);
    if (img != null) setState(() => _images.add(img));
  }

  void _send(String finalModel, String finalPlate) async {
    final String time = DateFormat('dd/MM/yyyy HH:mm').format(_targetTime);
    final String targetEmail = _emailCtrl.text.trim();
    final String description = _descCtrl.text.trim().isEmpty 
        ? 'Xe gặp sự cố ngập lụt, cần cứu hộ và giám định bảo hiểm.' 
        : _descCtrl.text.trim();

    final body = '''
Kính gửi Công ty Bảo hiểm,

Tôi xin gửi báo cáo yêu cầu bồi thường bảo hiểm cho sự cố ngập nước (Nguồn ghi nhận: $_sourceName).

THÔNG TIN PHƯƠNG TIỆN:
- Biển số: $finalPlate
- Dòng xe: $finalModel

THÔNG TIN SỰ CỐ:
- Thời gian: $time
- Vị trí: $_address (${_coords?.latitude}, ${_coords?.longitude})
- Mô tả tình trạng: $description

Tôi đã đính kèm hình ảnh hiện trường ghi nhận từ hệ thống FloodGuard Safety. Rất mong quý công ty sớm xem xét và phản hồi.

Trân trọng,
FloodGuard Safety System
''';

    final String subject = 'Yêu cầu bồi thường bảo hiểm - Xe $finalPlate - $time';

    try {
      if (_images.isEmpty) {
        final Uri emailUri = Uri(
          scheme: 'mailto',
          path: targetEmail,
          query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
        );
        // ignore: deprecated_member_use
        await url_launcher.launch(emailUri.toString());
      } else {
        await Share.shareXFiles(_images, subject: subject, text: body);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể mở mail: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: C.bg(context),
      appBar: topBar(context, 'Lập hồ sơ bảo hiểm',
        left: canPop ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
          if (_step > 0) setState(() => _step--);
          else Navigator.pop(context);
        }) : null,
      ),
      body: Column(children: [
        _stepper(),
        Expanded(child: _buildStepContent()),
        _navigationButtons(),
      ]),
    );
  }

  Widget _stepper() => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    color: C.surface(context),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(4, (i) => Container(width: 40, height: 4, decoration: BoxDecoration(color: _step >= i ? C.brand(context) : C.line(context), borderRadius: BorderRadius.circular(2))))),
  );

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _stepLocation();
      case 1: return _stepImages();
      case 2: return _stepDetails();
      case 3: return _stepPreview();
      default: return const SizedBox();
    }
  }

  void _deleteSOS(SOSRequest sos) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Xóa?'), content: const Text('Xóa khỏi danh sách?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red)))]));
    if (confirm == true) {
      await FirebaseService.deleteSOSRequest(sos.id);
      setState(() => _recentSOS.removeWhere((item) => item.id == sos.id));
    }
  }

  Widget _stepLocation() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Bước 1: Xác định vị trí sự cố', style: T.title(context)),
        const SizedBox(height: 24),
        
        // LUÔN HIỂN THỊ MỤC SOS GẦN ĐÂY (VẤN ĐỀ 1)
        Text('SOS GẦN ĐÂY', style: T.caption(context).copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_recentSOS.isNotEmpty) 
          ..._recentSOS.map((sos) => ListTile(
            onTap: () => _useSOSLocation(sos),
            selected: _selectedSOSId == sos.id,
            leading: Icon(Icons.history, color: _selectedSOSId == sos.id ? C.brand(context) : null),
            title: Text('${sos.vehicleModel} (${sos.vehiclePlate})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('${_getTimeAgo(sos.createdAt)} · Ngập ${sos.waterCm}cm', style: const TextStyle(fontSize: 11)),
            trailing: _selectedSOSId == sos.id ? Icon(Icons.check_circle, color: C.brand(context)) : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _deleteSOS(sos)),
          ))
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
            child: Text('Chưa có SOS gần đây', style: T.small(context, Colors.grey)),
          ),
        
        const SizedBox(height: 24),
        Text('NGUỒN KHÁC', style: T.caption(context).copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _locationOption('Vị trí hiện tại', 'Lấy GPS ngay lúc này', Icons.my_location, _useCurrentLocation, active: _sourceName == 'Vị trí hiện tại'),
        
        const SizedBox(height: 24),
        Text('Tự nhập địa chỉ:', style: T.small(context).copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(controller: _searchCtrl, onChanged: _onSearchChanged, decoration: const InputDecoration(hintText: 'Tìm địa điểm...', prefixIcon: Icon(Icons.search))),
        if (_searchResults.isNotEmpty) Column(children: _searchResults.map((p) => ListTile(title: Text(p.name), subtitle: Text(p.address), onTap: () => _selectPlace(p))).toList()),
        const SizedBox(height: 32),
        _vehicleSourceDisplay(),
      ],
    );
  }

  Widget _vehicleSourceDisplay() {
    if (_manualVehicleModel != null) {
      return _infoBox('$_manualVehicleModel ($_manualVehiclePlate)');
    }
    return StreamBuilder<VehicleData?>(
      stream: FirebaseService.streamCurrentVehicle(),
      builder: (context, snap) {
        final v = snap.data;
        if (snap.connectionState == ConnectionState.waiting) return _infoBox('Đang tải...');
        return _infoBox(v != null ? '${v.model} (${v.plate})' : 'Chưa có xe');
      },
    );
  }

  Widget _infoBox(String carInfo) => AppCard(color: C.brandBg(context).withValues(alpha: 0.5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('DỮ LIỆU ĐÃ CHỌN', style: T.caption(context).copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Xe: $carInfo', style: T.body(context).copyWith(fontWeight: FontWeight.bold, color: C.brand(context))), Text('Địa chỉ: $_address', style: T.small(context))]));

  Widget _locationOption(String title, String sub, IconData icon, VoidCallback onTap, {bool active = false}) => ListTile(onTap: onTap, selected: active, leading: Icon(icon, color: active ? C.brand(context) : null), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(sub), trailing: active ? Icon(Icons.check_circle, color: C.brand(context)) : null);

  Widget _stepImages() => ListView(padding: const EdgeInsets.all(24), children: [Text('Bước 2: Ảnh chụp hiện trường', style: T.title(context)), const SizedBox(height: 24), GridView.count(shrinkWrap: true, crossAxisCount: 2, children: [..._images.map((img) => Stack(children: [Image.file(File(img.path), fit: BoxFit.cover), Positioned(right: 0, child: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _images.remove(img))))])), GestureDetector(onTap: _pickImage, child: Container(color: C.brandBg(context), child: const Icon(Icons.add_a_photo)))])]);

  Widget _stepDetails() => ListView(padding: const EdgeInsets.all(24), children: [Text('Bước 3: Mô tả', style: T.title(context)), const SizedBox(height: 24), AppInput(label: 'Tình trạng', controller: _descCtrl), const SizedBox(height: 16), AppInput(label: 'Email nhận hồ sơ', controller: _emailCtrl)]);

  Widget _stepPreview() {
    return StreamBuilder<VehicleData?>(
      stream: FirebaseService.streamCurrentVehicle(),
      builder: (context, snap) {
        final v = snap.data;
        final String model = _manualVehicleModel ?? v?.model ?? '...';
        final String plate = _manualVehiclePlate ?? v?.plate ?? '...';
        return ListView(padding: const EdgeInsets.all(24), children: [
          Text('Bước 4: Kiểm tra', style: T.title(context)),
          const SizedBox(height: 24),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row('Nguồn', _sourceName),
            _row('Phương tiện', '$model ($plate)'),
            _row('Thời gian', DateFormat('HH:mm dd/MM').format(_targetTime)),
            _row('Vị trí', _address),
            const Divider(),
            Text(_descCtrl.text.isEmpty ? 'Không có mô tả' : _descCtrl.text),
          ])),
          const SizedBox(height: 24),
          AppButton('Gửi báo cáo', onTap: () => _send(model, plate)),
        ]);
      }
    );
  }

  Widget _row(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: T.caption(context)), Text(v, style: T.small(context).copyWith(fontWeight: FontWeight.bold))]));

  Widget _navigationButtons() => Container(padding: const EdgeInsets.all(24), child: Row(children: [_step > 0 ? Expanded(child: AppButton('Quay lại', tone: Tone.ghost, onTap: () => setState(() => _step--))) : const SizedBox(), const SizedBox(width: 16), Expanded(child: AppButton(_step == 3 ? 'Gửi báo cáo' : 'Tiếp theo', onTap: () { if(_step < 3) setState(() => _step++); }))]));
}
