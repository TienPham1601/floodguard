import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/vehicle_state.dart';
import '../../data/device_service.dart';

class ThresholdScreen extends StatefulWidget {
  const ThresholdScreen({super.key});
  @override
  State<ThresholdScreen> createState() => _ThresholdScreenState();
}

class _ThresholdScreenState extends State<ThresholdScreen> {
  late double warn = vehicle.warnAt;
  late double danger = vehicle.dangerAt;
  late double height = vehicle.sensorHeight;

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Thiết lập cảm biến',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          const AlertBanner(
            level: Level.safe,
            icon: Icons.info_outline,
            text: 'Các ngưỡng này giúp thiết bị tự động bảo vệ xe khi bạn không có mặt.',
          ),
          const SizedBox(height: S.x4),
          _slider(context, 'Mực nước cảnh báo', '${warn.toStringAsFixed(0)} cm', warn, 5, 55, C.warn(context),
              'Thông báo và rung điện thoại', (v) {
                setState(() {
                  warn = v;
                  if (danger < warn + 5) danger = (warn + 5).clamp(5, 60);
                });
              }),
          const SizedBox(height: S.x4),
          _slider(context, 'Mực nước nguy hiểm', '${danger.toStringAsFixed(0)} cm', danger, warn + 5, 60, C.danger(context),
              'Tự động đóng cổ hút và gọi cứu hộ', (v) => setState(() => danger = v)),
          const SizedBox(height: S.x4),
          _slider(context, 'Chiều cao lắp cảm biến', '${height.toStringAsFixed(0)} cm', height, 10, 100, C.brand(context),
              'Khoảng cách từ cảm biến tới mặt đất', (v) => setState(() => height = v)),
          const SizedBox(height: S.x5),
          AppButton('Lưu & Đồng bộ thiết bị', onTap: () {
            vehicle.saveThresholds(warn, danger, newHeight: height);
            
            // Gửi lệnh xuống thiết bị
            deviceService.sendCommand("SET_WARN:${warn.toInt()}");
            deviceService.sendCommand("SET_DANGER:${danger.toInt()}");
            deviceService.sendCommand("SET_HEIGHT:${height.toInt()}");
            
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật cấu hình thiết bị.')));
          }),
        ],
      ),
    );
  }

  Widget _slider(BuildContext c, String title, String value, double v, double min, double max, Color color, String note, ValueChanged<double> onChanged) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: T.body(c).copyWith(fontWeight: FontWeight.w500)),
          Text(value, style: T.mono(c, color).copyWith(fontSize: 16)),
        ]),
        SliderTheme(
          data: SliderTheme.of(c).copyWith(activeTrackColor: color, thumbColor: color),
          child: Slider(value: v, min: min, max: max, onChanged: onChanged),
        ),
        Text(note, style: T.caption(c)),
      ]),
    );
  }
}
