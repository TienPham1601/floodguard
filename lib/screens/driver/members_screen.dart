import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, 'Xe của tôi',
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          right: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Thêm xe mới',
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AddVehicleScreen())),
            )
          ]),
      child: StreamBuilder<List<VehicleData>>(
        stream: FirebaseService.streamAllUserVehicles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final vehicles = snapshot.data ?? [];
          if (vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_outlined, size: 64, color: C.muted(context)),
                  const SizedBox(height: 16),
                  Text('Bạn chưa có xe nào', style: T.title(context)),
                  const SizedBox(height: 8),
                  AppButton('Thêm xe ngay', full: false, onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const AddVehicleScreen()))),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(S.x4),
            children: [
              _label(context, 'PHƯƠNG TIỆN CỦA BẠN'),
              for (var v in vehicles) ...[
                _vehicle(context, v.id, v.plate, v.model, true,
                    onTap: () {
                      FirebaseService.selectVehicle(v.id);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => VehicleDetailScreen(
                            vehicleId: v.id,
                            plate: v.plate, 
                            model: v.model)));
                    }),
                const SizedBox(height: S.x2),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _label(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t, style: T.caption(c).copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _vehicle(BuildContext c, String id, String plate, String model, bool active, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: C.surface(c),
          border: Border.all(color: C.line(c)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plate, style: T.body(c).copyWith(fontWeight: FontWeight.w600)),
                Text(model, style: T.small(c)),
              ]),
            ),
            Icon(Icons.chevron_right, size: 18, color: C.muted(c)),
          ]),
        ),
      ),
    );
  }
}
