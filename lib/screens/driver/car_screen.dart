import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'pair_device_screen.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/vehicle_state.dart';
import '../../data/app_settings.dart';
import '../../data/firebase_service.dart';
import '../../data/device_service.dart';
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
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _initGPS();
    _listenToDeviceEvents();
  }

  void _listenToDeviceEvents() {
    _eventSub = deviceService.eventStream.listen((event) {
      if (!mounted) return;
      
      final String type = event['type'];
      final String msg = event['message'];

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (type == 'warning') const Text('Vui lòng kiểm tra xe ngay lập tức.'),
            ],
          ),
          backgroundColor: type == 'danger' ? Colors.red : Colors.orange,
          duration: const Duration(seconds: 10),
          action: type == 'warning' 
            ? SnackBarAction(
                label: 'ĐÓNG CỔ HÚT', 
                textColor: Colors.white,
                onPressed: () => deviceService.sendCommand("INTAKE_CLOSE")
              )
            : null,
        )
      );
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _initGPS() async {
    final pos = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _currentGPS = pos);
    }
  }

  void _toggleIntake() {
    if (vehicle.intakeClosed) {
      deviceService.sendCommand("INTAKE_OPEN");
    } else {
      deviceService.sendCommand("INTAKE_CLOSE");
    }
  }

  void _togglePower() async {
    if (!vehicle.powerCut) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ngắt nguồn điện ô tô?'),
          content: const Text('Xe sẽ không khởi động được cho tới khi bạn khôi phục nguồn. Chỉ dùng khi thực sự cần thiết.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
            TextButton(
              onPressed: () => Navigator.pop(c, true), 
              child: const Text('Ngắt nguồn', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            ),
          ],
        )
      );
      if (ok == true) {
        deviceService.sendCommand("POWER_CUT");
      }
    } else {
      deviceService.sendCommand("POWER_ON");
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

  void _showDeviceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(vehicle.connectedDeviceName ?? 'Thiết bị FloodGuard', style: T.title(ctx)),
            const SizedBox(height: 8),
            const Divider(),
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                deviceService.disconnect();
              },
              leading: const Icon(Icons.bluetooth_disabled, color: Colors.orange),
              title: const Text('Ngắt kết nối tạm thời'),
              subtitle: const Text('Có thể tự động kết nối lại sau'),
            ),
            ListTile(
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Quên thiết bị?'),
                    content: const Text('Xoá lịch sử ghép nối. Bạn sẽ cần quét lại để kết nối thiết bị này.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quên ngay', style: TextStyle(color: Colors.red))),
                    ],
                  )
                );
                if (ok == true) {
                  deviceService.forgetDevice();
                }
              },
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Quên thiết bị này', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Xoá dữ liệu ghép nối khỏi tài khoản'),
            ),
            const SizedBox(height: 20),
          ],
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

            // Cập nhật VehicleState (Single Source of Truth)
            vehicle.id = vehicleData.id;
            vehicle.plate = vehicleData.plate;
            vehicle.model = vehicleData.model;
            
            // Chỉ đồng bộ dữ liệu cảm biến từ DB nếu KHÔNG có kết nối thật
            if (!vehicle.isFullyValidated && !simulationMode.value) {
              vehicle.waterCm = vehicleData.waterCm.toDouble();
              vehicle.tempC = vehicleData.tempC.toDouble();
              vehicle.warnAt = vehicleData.warnAt.toDouble();
              vehicle.dangerAt = vehicleData.dangerAt.toDouble();
            }

            final lv = levelOf(vehicle.waterCm.toDouble(), vehicle.warnAt.toDouble(), vehicle.dangerAt.toDouble());
            final danger = lv == Level.danger;
            final warn = lv == Level.warn;

            final LatLng displayPos = _currentGPS ?? defaultLocation;

            return ListView(
              padding: const EdgeInsets.all(S.x4),
              children: [
                // Simulation Mode Banner
                ValueListenableBuilder<bool>(
                  valueListenable: simulationMode,
                  builder: (context, isSim, _) => isSim 
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: const Text('CHẾ ĐỘ MÔ PHỎNG - DỮ LIỆU GIẢ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    : const SizedBox.shrink(),
                ),

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
                  builder: (context, _) {
                    String title = 'Thiết bị FloodGuard';
                    String sub = 'Chưa kết nối thiết bị';
                    Color subColor = Colors.red.shade700;
                    Widget? action;

                    if (vehicle.isConnecting) {
                      title = vehicle.connectedDeviceName ?? 'FloodGuard';
                      sub = 'Đang kết nối...';
                      subColor = Colors.orange.shade700;
                      action = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
                    } else if (vehicle.isConnected) {
                      title = vehicle.connectedDeviceName ?? 'FloodGuard';
                      sub = 'Đang hoạt động realtime';
                      subColor = Colors.green.shade700;
                      action = IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showDeviceOptions(context),
                      );
                    } else if (vehicle.reconnectFailed) {
                       title = vehicle.connectedDeviceName ?? 'FloodGuard';
                       sub = 'Không tìm thấy thiết bị';
                       subColor = Colors.red.shade700;
                       action = Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: () => deviceService.initAutoConnect()),
                          IconButton(icon: const Icon(Icons.bluetooth_searching, size: 18), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairDeviceScreen()))),
                       ]);
                    } else {
                      action = AppButton('Kết nối', full: false, height: 32, padding: const EdgeInsets.symmetric(horizontal: 12), 
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairDeviceScreen())));
                    }

                    return AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: vehicle.isConnected ? Colors.green.shade50 : (vehicle.isConnecting ? Colors.orange.shade50 : Colors.grey.shade100), 
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: Icon(
                            vehicle.isConnected ? Icons.bluetooth_connected : (vehicle.isConnecting ? Icons.bluetooth_searching : Icons.bluetooth_disabled), 
                            color: vehicle.isConnected ? Colors.green : (vehicle.isConnecting ? Colors.orange : Colors.grey)
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: T.body(context).copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(sub, style: T.caption(context).copyWith(color: subColor, fontWeight: FontWeight.bold)),
                        ])),
                        action,
                      ]),
                    );
                  },
                ).animate().fade().slideY(begin: 0.2),

                const SizedBox(height: S.x4),

                ListenableBuilder(
                  listenable: vehicle,
                  builder: (context, _) => HeroStatus(
                    cm: vehicle.waterCm, 
                    warnAt: vehicle.warnAt, 
                    dangerAt: vehicle.dangerAt,
                    isWet: vehicle.isWet,
                  ),
                ).animate().scale(delay: const Duration(milliseconds: 100)),
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
                    ]),
                  ),
                  const SizedBox(height: S.x4),
                  AppButton('GỬI TÍN HIỆU SOS', icon: Icons.sos, tone: Tone.danger, height: 56, onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FullAlertScreen.flood(cm: vehicle.waterCm.toInt())));
                  }),
                  const SizedBox(height: S.x2),
                  AppButton('Mở lại cổ hút', tone: Tone.ghost, onTap: _toggleIntake),
                ] else ...[
                  RowItem(
                    icon: Icons.airline_seat_recline_normal,
                    iconColor: C.safe(context),
                    iconBg: C.safeBg(context),
                    title: 'Cabin',
                    sub: '${vehicle.tempC.toStringAsFixed(0)}°C · độ ẩm ${vehicle.humidity.toStringAsFixed(0)}%',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CabinScreen())),
                  ),
                  const SizedBox(height: S.x4),
                  ListenableBuilder(
                    listenable: vehicle,
                    builder: (context, _) => Row(children: [
                      Expanded(
                        child: AppButton(
                          vehicle.intakeClosed ? 'Mở cổ hút' : (warn ? 'Đóng cổ hút' : 'Cổ hút'),
                          icon: Icons.air,
                          tone: warn ? Tone.soft : Tone.ghost,
                          enabled: vehicle.isConnected,
                          onTap: _toggleIntake,
                        ),
                      ),
                      const SizedBox(width: S.x3),
                      Expanded(
                        child: AppButton(
                          vehicle.powerCut ? 'Cấp nguồn' : 'Ngắt nguồn',
                          icon: Icons.power_settings_new, 
                          tone: vehicle.powerCut ? Tone.soft : Tone.ghost,
                          enabled: vehicle.isConnected,
                          onTap: _togglePower,
                        ),
                      ),
                    ]),
                  ),
                  if (!vehicle.isConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(child: Text('Cần kết nối thiết bị để điều khiển', style: T.caption(context).copyWith(color: Colors.red))),
                    ),
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
