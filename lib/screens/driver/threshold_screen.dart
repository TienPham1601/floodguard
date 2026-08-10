import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/vehicle_state.dart';

class ThresholdScreen extends StatefulWidget {
  const ThresholdScreen({super.key});
  @override
  State<ThresholdScreen> createState() => _ThresholdScreenState();
}

class _ThresholdScreenState extends State<ThresholdScreen> {
  late double warn = vehicle.warnAt;
  late double danger = vehicle.dangerAt;
  double tempWarn = 45;
  double humidity = 75;

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Ngưỡng cảnh báo',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          const AlertBanner(
            level: Level.safe,
            icon: Icons.info_outline,
            text: 'Giá trị mặc định tính theo Toyota Vios 2020, khoảng sáng gầm 150mm.',
          ),
          const SizedBox(height: S.x4),
          _slider(context, 'Mực nước cảnh báo', '${warn.toStringAsFixed(0)} cm', warn, 5, 34, C.warn(context),
              'Rung và hiện thông báo', (v) => setState(() => warn = v)),
          const SizedBox(height: S.x4),
          _slider(context, 'Mực nước nguy hiểm', '${danger.toStringAsFixed(0)} cm', danger, warn + 1, 50, C.danger(context),
              'Tự động đóng cổ hút và ngắt nguồn', (v) => setState(() => danger = v)),
          const SizedBox(height: S.x4),
          _slider(context, 'Nhiệt độ cabin', '${tempWarn.toStringAsFixed(0)} °C', tempWarn, 35, 55, C.warn(context),
              'Cảnh báo sốc nhiệt khi có người trong xe', (v) => setState(() => tempWarn = v)),
          const SizedBox(height: S.x4),
          _slider(context, 'Độ ẩm cabin', '${humidity.toStringAsFixed(0)} %', humidity, 50, 90, C.brand(context),
              'Cảnh báo nếu duy trì liên tục 24 giờ', (v) => setState(() => humidity = v)),
          const SizedBox(height: S.x5),
          AppButton('Lưu thay đổi', onTap: () {
            vehicle.saveThresholds(warn, danger);
            Navigator.pop(context);
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
