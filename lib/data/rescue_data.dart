import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Trạng thái vòng đời của một yêu cầu cứu hộ.
enum ReqStatus { waiting, accepted, arrived, done, dismissed }

/// Yêu cầu cứu hộ. Điểm mấu chốt: thông tin định danh chỉ mở khi đã nhận việc.
/// Đây là hiện thực của SosRequest.visibleTo() — quyền xem gắn với TRẠNG THÁI,
/// không gắn với vai. Trước khi nhận, đội cứu hộ chỉ thấy đủ để quyết định đi hay không.
class SosRequest {
  final String id;
  final String plateFull; // 51A-123.45
  final String vehicleType; // Sedan
  final String model; // Toyota Vios 2020
  final String ownerName;
  final String ownerPhone;
  final String areaName; // khu vực (làm tròn) — Nguyễn Hữu Cảnh, Bình Thạnh
  final String exactAddress; // địa chỉ chính xác — chỉ hiện sau khi nhận
  final String coords; // toạ độ dạng chữ — chỉ hiện sau khi nhận
  final LatLng pos; // toạ độ trên bản đồ
  final int waterCm;
  final bool personInside;
  final bool powerCut;
  final bool intakeClosed;
  final String risingRate; // +3cm / 10 phút
  final int minutesAgo;
  final double distanceKm;

  ReqStatus status;

  SosRequest({
    required this.id,
    required this.plateFull,
    required this.vehicleType,
    required this.model,
    required this.ownerName,
    required this.ownerPhone,
    required this.areaName,
    required this.exactAddress,
    required this.coords,
    required this.pos,
    required this.waterCm,
    required this.personInside,
    required this.powerCut,
    required this.intakeClosed,
    required this.risingRate,
    required this.minutesAgo,
    required this.distanceKm,
    this.status = ReqStatus.waiting,
  });

  bool get unlocked => status == ReqStatus.accepted || status == ReqStatus.arrived || status == ReqStatus.done;

  /// Biển số: che khi chưa nhận (51A-***.**), đầy đủ khi đã nhận.
  String get plate {
    if (unlocked) return plateFull;
    final dash = plateFull.indexOf('-');
    if (dash <= 0) return '***';
    return '${plateFull.substring(0, dash)}-***.**';
  }

  /// Tên chủ xe: ẩn khi chưa nhận.
  String get owner => unlocked ? ownerName : 'Hiện sau khi nhận';

  /// Số điện thoại: ẩn khi chưa nhận.
  String get phone => unlocked ? ownerPhone : 'Hiện sau khi nhận';

  /// Vị trí: khu vực làm tròn khi chưa nhận, địa chỉ + toạ độ khi đã nhận.
  String get locationLabel => unlocked ? exactAddress : areaName;
  String get distanceLabel => unlocked ? '${distanceKm.toStringAsFixed(1)} km' : '~${distanceKm.toStringAsFixed(1)} km';
}

/// Kho dữ liệu cứu hộ (mô phỏng). Khi có backend, thay phần nạp dữ liệu ở đây.
class RescueData extends ChangeNotifier {
  final List<SosRequest> requests = [
    SosRequest(
      id: '2471',
      plateFull: '51A-123.45',
      vehicleType: 'Sedan',
      model: 'Toyota Vios 2020',
      ownerName: 'Phạm Thu',
      ownerPhone: '0912 448 209',
      areaName: 'Nguyễn Hữu Cảnh, Bình Thạnh',
      exactAddress: '142 Nguyễn Hữu Cảnh',
      coords: '10.7982, 106.7215',
      pos: const LatLng(10.7982, 106.7215),
      waterCm: 38,
      personInside: false,
      powerCut: true,
      intakeClosed: true,
      risingRate: '+3cm / 10 phút',
      minutesAgo: 1,
      distanceKm: 2.4,
    ),
    SosRequest(
      id: '2472',
      plateFull: '59F-887.21',
      vehicleType: 'Sedan',
      model: 'Honda City 2019',
      ownerName: 'Trần Văn Nam',
      ownerPhone: '0903 771 208',
      areaName: 'Nguyễn Hữu Cảnh, Bình Thạnh',
      exactAddress: '88 Nguyễn Hữu Cảnh',
      coords: '10.7975, 106.7220',
      pos: const LatLng(10.7975, 106.7220),
      waterCm: 41,
      personInside: true,
      powerCut: true,
      intakeClosed: true,
      risingRate: '+5cm / 10 phút',
      minutesAgo: 4,
      distanceKm: 2.6,
    ),
    SosRequest(
      id: '2473',
      plateFull: '51G-204.77',
      vehicleType: 'Sedan',
      model: 'Mazda 3 2021',
      ownerName: 'Lê Thị Hoa',
      ownerPhone: '0938 552 019',
      areaName: 'Điện Biên Phủ, Bình Thạnh',
      exactAddress: '210 Điện Biên Phủ',
      coords: '10.8010, 106.7112',
      pos: const LatLng(10.8010, 106.7112),
      waterCm: 29,
      personInside: false,
      powerCut: false,
      intakeClosed: false,
      risingRate: '+2cm / 10 phút',
      minutesAgo: 11,
      distanceKm: 3.1,
    ),
  ];

  SosRequest? get active {
    for (final r in requests) {
      if (r.status == ReqStatus.accepted || r.status == ReqStatus.arrived) return r;
    }
    return null;
  }

  List<SosRequest> get waitingList =>
      requests.where((r) => r.status == ReqStatus.waiting).toList();

  SosRequest byId(String id) => requests.firstWhere((r) => r.id == id);

  void accept(String id) {
    byId(id).status = ReqStatus.accepted;
    notifyListeners();
  }

  void finish(String id) {
    byId(id).status = ReqStatus.done;
    notifyListeners();
  }

  void cancel(String id) {
    byId(id).status = ReqStatus.waiting;
    notifyListeners();
  }

  /// Báo cho giao diện vẽ lại sau khi sửa trực tiếp danh sách.
  void notify() => notifyListeners();

  /// Bỏ qua: yêu cầu biến khỏi danh sách của đơn vị này.
  void dismiss(String id) {
    byId(id).status = ReqStatus.dismissed;
    notifyListeners();
  }

  /// Đánh dấu đã tới hiện trường.
  void markArrived(String id) {
    byId(id).status = ReqStatus.arrived;
    notifyListeners();
  }
}

final rescue = RescueData();

/// Vị trí đơn vị cứu hộ (Gara Minh Phát, đường D2 Bình Thạnh).
const rescueBase = LatLng(10.8035, 106.7160);

/// Yêu cầu đang được dẫn đường tới. Đặt giá trị này rồi chuyển sang tab Bản đồ.
final navigateTo = ValueNotifier<SosRequest?>(null);
