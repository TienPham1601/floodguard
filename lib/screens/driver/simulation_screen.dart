import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/vehicle_state.dart';
import '../../data/app_settings.dart';
import 'full_alert_screen.dart';

/// Bảng điều khiển mô phỏng — thay cho thiết bị thật khi chưa lắp,
/// và dùng để chạy kịch bản lúc demo trước hội đồng.
class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  @override
  void initState() {
    super.initState();
    vehicle.addListener(_refresh);
  }

  @override
  void dispose() {
    vehicle.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Mô phỏng',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Dải cố định nhắc đây là dữ liệu giả
          Container(
            width: double.infinity,
            height: 28,
            alignment: Alignment.center,
            color: C.warn(context),
            child: Text('DỮ LIỆU MÔ PHỎNG · KHÔNG PHẢI SỐ ĐO THẬT',
                style: T.caption(context, Colors.white).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
          Padding(
            padding: const EdgeInsets.all(S.x4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('KỊCH BẢN DỰNG SẴN', style: T.caption(context).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _scenario(context, Icons.water_drop, C.danger(context), C.dangerBg(context),
                  'Mưa lớn, nước dâng', '8cm → 38cm · đi qua cả 3 mức', () {
                vehicle.setWater(38);
                _toast(context, 'Đã đặt mực nước 38cm — mức Nguy hiểm');
              }),
              const SizedBox(height: S.x3),
              _scenario(context, Icons.thermostat, C.warn(context), C.warnBg(context),
                  'Cabin nóng, có người', '31°C → 43,6°C · bật cảnh báo khẩn', () {
                vehicle.setCabin(tempC: 43.6, personInside: true);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FullAlertScreen.person(tempC: 43.6, minutes: 6)));
              }),
              const SizedBox(height: S.x3),
              _scenario(context, Icons.check_circle, C.safe(context), C.safeBg(context),
                  'Về bình thường', 'Đưa mọi chỉ số về mức an toàn', () {
                vehicle.resetToSafe();
                _toast(context, 'Đã đưa mọi chỉ số về mức an toàn');
              }),

              const SizedBox(height: S.x5),
              Text('ĐIỀU KHIỂN THỦ CÔNG', style: T.caption(context).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              AppCard(
                child: Column(children: [
                  _slider(context, 'Mực nước', '${vehicle.waterCm.toStringAsFixed(0)} cm',
                      vehicle.waterCm, 0, 50, C.of(context, levelOf(vehicle.waterCm, vehicle.warnAt, vehicle.dangerAt)),
                      vehicle.setWater),
                  const SizedBox(height: 8),
                  _slider(context, 'Nhiệt độ cabin', '${vehicle.tempC.toStringAsFixed(1)} °C',
                      vehicle.tempC, 20, 60, vehicle.tempC >= 40 ? C.warn(context) : C.brand(context),
                      (v) => vehicle.setCabin(tempC: v)),
                  const SizedBox(height: 8),
                  _slider(context, 'Độ ẩm', '${vehicle.humidity.toStringAsFixed(0)} %',
                      vehicle.humidity, 30, 95, C.brand(context),
                      (v) => vehicle.setCabin(humidity: v)),
                  const SizedBox(height: 8),
                  _slider(context, 'Bụi mịn PM2.5', '${vehicle.pm25.toStringAsFixed(0)} µg/m³',
                      vehicle.pm25, 0, 150, C.brand(context),
                      (v) => vehicle.setCabin(pm25: v)),
                  const Divider(height: 28),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Có người trong xe', style: T.body(context)),
                        Text('Bật để thử cảnh báo quên người', style: T.caption(context)),
                      ]),
                    ),
                    Switch(
                      value: vehicle.personInside,
                      onChanged: (v) => vehicle.setCabin(personInside: v),
                    ),
                  ]),
                ]),
              ),

              const SizedBox(height: S.x4),
              Text('XEM THỬ MÀN CẢNH BÁO', style: T.caption(context).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              AppButton('Cảnh báo ngập khi đang lái', icon: Icons.warning_amber_rounded, tone: Tone.soft,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FullAlertScreen.flood(cm: vehicle.waterCm.toInt().clamp(36, 60))))),
              const SizedBox(height: S.x3),
              AppButton('Cảnh báo còn người trên xe', icon: Icons.child_care, tone: Tone.soft,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FullAlertScreen.person(tempC: 43.6, minutes: 6)))),

              const SizedBox(height: S.x5),
              AppButton('Tắt chế độ mô phỏng', tone: Tone.ghost, onTap: () {
                simulationMode.value = false;
                vehicle.resetToSafe();
                Navigator.pop(context);
              }),
              const SizedBox(height: S.x6),
            ]),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext c, String msg) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Widget _scenario(BuildContext c, IconData icon, Color fg, Color bg, String title, String sub, VoidCallback onTap) {
    return Material(
      color: C.surface(c),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: C.line(c)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.body(c).copyWith(fontWeight: FontWeight.w600)),
                Text(sub, style: T.small(c)),
              ]),
            ),
            Icon(Icons.play_arrow, size: 20, color: C.muted(c)),
          ]),
        ),
      ),
    );
  }

  Widget _slider(BuildContext c, String label, String value, double v, double min, double max,
      Color color, ValueChanged<double> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: T.body(c).copyWith(fontSize: 14)),
        Text(value, style: T.mono(c, color).copyWith(fontSize: 15)),
      ]),
      SliderTheme(
        data: SliderTheme.of(c).copyWith(
          activeTrackColor: color,
          thumbColor: color,
          trackHeight: 3,
        ),
        child: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ),
    ]);
  }
}
