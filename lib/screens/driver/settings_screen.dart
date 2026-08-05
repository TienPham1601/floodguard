import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/app_settings.dart';
import '../../data/firebase_service.dart';
import 'simulation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _rescuePhone = TextEditingController();
  final _insuranceEmail = TextEditingController();
  final _relativePhone = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.streamUserProfile(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data != null) {
          _rescuePhone.text = data['emergencyRescue'] ?? '';
          _insuranceEmail.text = data['insuranceEmail'] ?? '';
          _relativePhone.text = data['relativePhone'] ?? '';
        }

        return Screen(
          bar: topBar(context, 'Cài đặt',
              left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _label(context, 'LIÊN HỆ KHẨN CẤP'),
              _inputRow(context, 'Số cứu hộ mặc định', _rescuePhone, 'emergencyRescue'),
              _inputRow(context, 'Email bảo hiểm', _insuranceEmail, 'insuranceEmail', type: TextInputType.emailAddress),
              _inputRow(context, 'Người thân nhận cảnh báo', _relativePhone, 'relativePhone', type: TextInputType.phone),

              _label(context, 'THÔNG BÁO'),
              _switchDbRow(context, 'Âm thanh và rung', 'allowSound', data?['allowSound'] ?? true),
              _switchDbRow(context, 'Bỏ qua chế độ im lặng', 'ignoreSilent', data?['ignoreSilent'] ?? false),

              _label(context, 'GIAO DIỆN'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeMode,
                builder: (context, mode, _) => _switchRow(
                  context,
                  'Chế độ tối',
                  mode == ThemeMode.dark,
                  (v) => themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              _static(context, 'Đơn vị đo', '${data?['unitWater'] ?? 'cm'} · ${data?['unitTemp'] ?? '°C'}'),

              _label(context, 'HỆ THỐNG'),
              ValueListenableBuilder<bool>(
                valueListenable: simulationMode,
                builder: (context, on, _) => Column(children: [
                  _switchRow(context, 'Chế độ mô phỏng', on, (v) => simulationMode.value = v),
                  if (on)
                    _actionRow(context, Icons.tune, 'Mở bảng điều khiển mô phỏng', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulationScreen()))),
                ]),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      }
    );
  }

  Widget _label(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(t, style: T.caption(c).copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      );

  Widget _inputRow(BuildContext c, String label, TextEditingController ctrl, String field, {TextInputType type = TextInputType.text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: C.surface(c), border: Border(bottom: BorderSide(color: C.line(c)))),
      child: Row(children: [
        Expanded(child: Text(label, style: T.body(c))),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            textAlign: TextAlign.right,
            style: T.small(c).copyWith(fontWeight: FontWeight.bold, color: C.brand(c)),
            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nhập...'),
            onSubmitted: (val) => FirebaseFirestore.instance.collection('users').doc(FirebaseService.auth.currentUser!.uid).update({field: val}),
          ),
        ),
      ]),
    );
  }

  Widget _switchDbRow(BuildContext c, String label, String field, bool value) {
    return _switchRow(c, label, value, (v) {
       FirebaseFirestore.instance.collection('users').doc(FirebaseService.auth.currentUser!.uid).update({field: v});
    });
  }

  Widget _switchRow(BuildContext c, String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: C.surface(c), border: Border(bottom: BorderSide(color: C.line(c)))),
      child: Row(children: [
        Expanded(child: Text(label, style: T.body(c))),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }

  Widget _static(BuildContext c, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: C.surface(c), border: Border(bottom: BorderSide(color: C.line(c)))),
      child: Row(children: [
        Expanded(child: Text(k, style: T.body(c))),
        Text(v, style: T.small(c).copyWith(fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _actionRow(BuildContext c, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: C.brandBg(c), border: Border(bottom: BorderSide(color: C.line(c)))),
        child: Row(children: [
          Icon(icon, size: 20, color: C.brand(c)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: T.body(c, C.brand(c)).copyWith(fontWeight: FontWeight.bold))),
          Icon(Icons.chevron_right, size: 18, color: C.brand(c)),
        ]),
      ),
    );
  }
}
