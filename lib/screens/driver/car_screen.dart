import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'pair_device_screen.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/vehicle_state.dart';
import '../../data/app_settings.dart';
import '../../data/firebase_service.dart';
import '../../data/places.dart';
import '../../data/location_service.dart';
import 'add_vehicle_screen.dart';
import 'cabin_screen.dart';
import 'full_alert_screen.dart';
import 'simulation_screen.dart';

class CarScreen extends StatefulWidget {
  const CarScreen({super.key});
  @override
  State<CarScreen> createState() => _CarScreenState();
}

class _CarScreenState extends State<CarScreen> {
  static const defaultLocation = LatLng(21.0285, 105.8542);
  LatLng? _currentGPS;

  @override
  void initState() {
    super.initState();
    _initGPS();
  }

  Future<void> _initGPS() async {
    final pos = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _currentGPS = pos);
    }
  }

  void _showVehicleSelector(BuildContext context, List<VehicleData> allVehicles, String currentId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chọn xe để theo dõi', style: T.title(ctx)),
              const SizedBox(height: 16),
              ...allVehicles.map((v) => ListTile(
                onTap: () {
                  FirebaseService.selectVehicle(v.id);
                  Navigator.pop(ctx);
                },
                leading: VehicleIcon(type: v.type, width: 50, height: 32),
                title: Text(v.model, style: T.body(ctx).copyWith(fontWeight: v.id == currentId ? FontWeight.w600 : FontWeight.normal)),
                subtitle: Text(v.plate, style: T.small(ctx)),
                trailing: v.id == currentId ? Icon(Icons.check_circle, color: C.safe(ctx)) : null,
              )),
              const Divider(),
              ListTile(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddVehicleScreen()));
                },
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Thêm xe mới'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VehicleData>>(
      stream: FirebaseService.streamAllUserVehicles(),
      builder: (context, allVehSnap) {
        final allVehicles = allVehSnap.data ?? [];

        return StreamBuilder<VehicleData?>(
          stream: FirebaseService.streamCurrentVehicle(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                   ShimmerBox(height: 52), SizedBox(height: 16),
                   ShimmerBox(height: 68), SizedBox(height: 16),
                   ShimmerBox(height: 180), SizedBox(height: 16),
                   ShimmerBox(height: 100),
                ],
              );
            }

            final vehicleData = snapshot.data;
            if (vehicleData == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car_outlined, size: 64, color: C.muted(context)),
                    const SizedBox(height: 16),
                    const Text('Bạn chưa thêm xe nào'),
                    const SizedBox(height: 8),
                    AppButton('Thêm xe ngay', full: false, onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const AddVehicleScreen()))),
                  ],
                ),
              );
            }

            // Cập nhật VehicleState (Single Source of Truth) cho simulation và alerts
            vehicle.id = vehicleData.id;
            vehicle.plate = vehicleData.plate;
            vehicle.model = vehicleData.model;
            vehicle.waterCm = vehicleData.waterCm.toDouble();
            vehicle.tempC = vehicleData.tempC.toDouble();
            vehicle.warnAt = vehicleData.warnAt.toDouble();
            vehicle.dangerAt = vehicleData.dangerAt.toDouble();

            final lv = levelOf(vehicle.waterCm.toDouble(), vehicle.warnAt.toDouble(), vehicle.dangerAt.toDouble());
            final danger = lv == Level.danger;
            final warn = lv == Level.warn;

            final LatLng displayPos = _currentGPS ?? defaultLocation;

            return ListView(
              padding: const EdgeInsets.all(S.x4),
              children: [
                // chọn xe
                Material(
                  color: C.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                  onTap: () => _showVehicleSelector(context, allVehicles, vehicleData.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: C.line(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    VehicleIcon(type: vehicleData.type, width: 64, height: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(vehicle.plate, style: T.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(vehicle.model, style: T.caption(context)),
                      ]),
                    ),
                    Icon(Icons.keyboard_arrow_down, color: C.muted(context)),
                  ]),
                ))),
                const SizedBox(height: S.x4),

                // Card Thiết bị FloodGuard
                ListenableBuilder(
                  listenable: vehicle,
                  builder: (context, _) => AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: vehicle.isConnected ? C.brandBg(context) : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.router, color: vehicle.isConnected ? C.brand(context) : Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(vehicle.isConnected ? 'FloodGuard-A3F2' : 'Thiết bị FloodGuard', style: T.body(context).copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(vehicle.isConnected ? 'Đã kết nối · pin ${vehicle.batteryLevel}% · ${vehicle.deviceVersion}' : 'Chưa kết nối thiết bị', style: T.caption(context).copyWith(color: vehicle.isConnected ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold)),
                      ])),
                      if (!vehicle.isConnected)
                        AppButton('Kết nối', full: false, height: 32, padding: const EdgeInsets.symmetric(horizontal: 12), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairDeviceScreen())))
                      else
                        const Icon(Icons.bluetooth_connected, size: 16, color: Colors.green),
                    ]),
                  ),
                ).animate().fade().slideY(begin: 0.2),

                const SizedBox(height: S.x4),

                HeroStatus(cm: vehicle.waterCm, warnAt: vehicle.warnAt, dangerAt: vehicle.dangerAt).animate().scale(delay: const Duration(milliseconds: 100)),
                const SizedBox(height: S.x4),
                
                // Vị trí xe (Reverse Geocoding) - ĐỒNG BỘ VỚI SOS
                FutureBuilder<String>(
                  future: SearchService.reverseGeocode(displayPos.latitude, displayPos.longitude),
                  builder: (context, addrSnap) {
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.location_on, color: C.brand(context), size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(addrSnap.data ?? 'Đang xác định vị trí...', style: T.small(context).copyWith(fontWeight: FontWeight.w500))),
                          ]),
                          if (addrSnap.hasData) ...[
                            const SizedBox(height: 4),
                            Text('${displayPos.latitude.toStringAsFixed(4)}, ${displayPos.longitude.toStringAsFixed(4)}', 
                                style: T.caption(context).copyWith(fontSize: 10)),
                          ],
                        ],
                      ),
                    );
                  }
                ),
                const SizedBox(height: S.x4),

                if (warn || danger) ...[
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('24 giờ qua', style: T.body(context).copyWith(fontWeight: FontWeight.w500, fontSize: 13)),
                        Text('cao nhất ${vehicle.waterCm.toStringAsFixed(0)}cm', style: T.caption(context)),
                      ]),
                      const SizedBox(height: 12),
                      const MiniChart(
                        values: [0.16, 0.14, 0.22, 0.20, 0.30, 0.38, 0.46, 0.58, 0.70, 0.82, 0.92, 1.0],
                        levels: [Level.safe, Level.safe, Level.safe, Level.safe, Level.safe, Level.safe, Level.safe, Level.safe, Level.warn, Level.warn, Level.warn, Level.warn],
                      ),
                    ]),
                  ),
                  const SizedBox(height: S.x4),
                ],

                if (danger) ...[
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(children: [
                      _kv(context, 'Cổ hút', vehicle.intakeClosed ? 'ĐÃ ĐÓNG' : 'MỞ',
                          vehicle.intakeClosed ? C.danger(context) : C.safe(context),
                          vehicle.intakeClosed ? C.dangerBg(context) : C.safeBg(context)),
                      _kv(context, 'Nguồn điện', vehicle.powerCut ? 'ĐÃ NGẮT' : 'BÌNH THƯỜNG',
                          vehicle.powerCut ? C.danger(context) : C.safe(context),
                          vehicle.powerCut ? C.dangerBg(context) : C.safeBg(context)),
                      _kv(context, 'Người trong xe', vehicle.personInside ? 'CÓ' : 'KHÔNG',
                          vehicle.personInside ? C.danger(context) : C.safe(context),
                          vehicle.personInside ? C.dangerBg(context) : C.safeBg(context)),
                    ]),
                  ),
                  const SizedBox(height: S.x4),
                  AppButton('GỬI TÍN HIỆU SOS', icon: Icons.sos, tone: Tone.danger, height: 56, onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FullAlertScreen.flood(cm: vehicle.waterCm.toInt())));
                  }),
                  const SizedBox(height: S.x2),
                  AppButton('Mở lại cổ hút', tone: Tone.ghost, onTap: vehicle.toggleIntake),
                ] else ...[
                  RowItem(
                    icon: Icons.airline_seat_recline_normal,
                    iconColor: C.safe(context),
                    iconBg: C.safeBg(context),
                    title: 'Cabin',
                    sub: '${vehicle.tempC.toStringAsFixed(0)}°C · độ ẩm ${vehicle.humidity.toStringAsFixed(0)}% · ${vehicle.personInside ? "có người" : "không có người"}',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CabinScreen())),
                  ),
                  const SizedBox(height: S.x4),
                  Row(children: [
                    Expanded(
                      child: AppButton(
                        vehicle.intakeClosed ? 'Mở cổ hút' : (warn ? 'Đóng cổ hút' : 'Cổ hút'),
                        icon: Icons.air,
                        tone: warn ? Tone.soft : Tone.ghost,
                        onTap: vehicle.toggleIntake,
                      ),
                    ),
                    const SizedBox(width: S.x3),
                    Expanded(
                      child: AppButton(vehicle.powerCut ? 'Cấp nguồn' : 'Nguồn',
                          icon: Icons.power_settings_new, tone: Tone.ghost, onTap: vehicle.togglePower),
                    ),
                  ]),
                ],

                const SizedBox(height: S.x6),
                ValueListenableBuilder<bool>(
                  valueListenable: simulationMode,
                  builder: (context, on, _) => on ? _demoControl(context) : const SizedBox.shrink(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _kv(BuildContext c, String k, String v, Color fg, Color bg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: T.small(c)),
        StatusTag(v, fg: fg, bg: bg),
      ]),
    );
  }

  Widget _demoControl(BuildContext c) {
    return Material(
      color: C.brandBg(c),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SimulationScreen())),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(S.x4),
          child: Row(children: [
            Icon(Icons.tune, size: 20, color: C.brand(c)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chế độ mô phỏng đang bật',
                    style: T.body(c, C.brand(c)).copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Mở bảng điều khiển để đổi mực nước, nhiệt độ',
                    style: T.caption(c, C.brand(c))),
              ]),
            ),
            Icon(Icons.chevron_right, size: 18, color: C.brand(c)),
          ]),
        ),
      ),
    );
  }
}
