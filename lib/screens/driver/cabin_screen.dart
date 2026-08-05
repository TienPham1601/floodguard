import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/vehicle_state.dart';

class CabinScreen extends StatelessWidget {
  const CabinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hot = vehicle.tempC >= 40;
    return Screen(
      bar: topBar(context, 'Cabin',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: ListView(
        padding: const EdgeInsets.all(S.x4),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(Icons.thermostat, size: 20, color: hot ? C.warn(context) : C.muted(context)),
                  const SizedBox(width: 9),
                  Text('Nhiệt độ trong xe', style: T.title(context).copyWith(fontSize: 16)),
                ]),
                if (hot) StatusTag('ĐANG TĂNG', fg: C.warn(context), bg: C.warnBg(context)),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(vehicle.tempC.toStringAsFixed(1), style: T.sensor(context, hot ? C.warn(context) : C.ink(context))),
                const SizedBox(width: 6),
                Text('°C', style: T.small(context)),
              ]),
              const SizedBox(height: 6),
              Text('Ngoài trời 34°C · ngưỡng cảnh báo 45°C', style: T.small(context)),
              const SizedBox(height: 14),
              const MiniChart(
                values: [0.30, 0.36, 0.44, 0.52, 0.62, 0.74, 0.86, 0.96],
                levels: [Level.safe, Level.safe, Level.safe, Level.safe, Level.warn, Level.warn, Level.warn, Level.warn],
              ),
            ]),
          ),
          const SizedBox(height: S.x4),
          Row(children: [
            Expanded(child: _mini(context, Icons.water_drop_outlined, 'Độ ẩm', vehicle.humidity.toStringAsFixed(0), '%')),
            const SizedBox(width: S.x3),
            Expanded(child: _mini(context, Icons.air, 'Bụi mịn PM2.5', vehicle.pm25.toStringAsFixed(0), 'µg/m³')),
          ]),
          const SizedBox(height: S.x4),
          RowItem(
            icon: Icons.person_outline,
            iconColor: C.safe(context),
            iconBg: C.safeBg(context),
            title: 'Người trong xe',
            sub: 'Radar quét mỗi 5 giây',
            trailing: StatusTag(vehicle.personInside ? 'CÓ' : 'KHÔNG CÓ',
                fg: vehicle.personInside ? C.danger(context) : C.safe(context),
                bg: vehicle.personInside ? C.dangerBg(context) : C.safeBg(context)),
          ),
          const SizedBox(height: S.x4),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lọc điều hoà', style: T.title(context).copyWith(fontSize: 15)),
              const SizedBox(height: 8),
              Text('Bụi mịn trong xe bằng 68% ngoài trời khi lấy gió ngoài. Lọc vẫn hoạt động tốt.',
                  style: T.small(context, C.ink(context)).copyWith(height: 1.7)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: 0.68,
                  minHeight: 6,
                  backgroundColor: C.bg(context),
                  valueColor: AlwaysStoppedAnimation(C.safe(context)),
                ),
              ),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Tốt', style: T.caption(context)),
                Text('Nên thay khi vượt 70%', style: T.caption(context)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _mini(BuildContext c, IconData icon, String label, String value, String unit) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 17, color: C.muted(c)),
          const SizedBox(width: 7),
          Text(label, style: T.caption(c)),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(value, style: T.mono(c)),
          const SizedBox(width: 3),
          Text(unit, style: T.small(c)),
        ]),
      ]),
    );
  }
}
