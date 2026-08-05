import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import '../../theme.dart';
import '../../ui.dart';
import '../../utils.dart';
import '../../data/rescue_data.dart';
import '../../widgets/app_map.dart';
import 'request_detail_screen.dart';

/// Bản đồ vai cứu hộ — dùng chung widget AppMap với vai tài xế.
/// Hiện yêu cầu SOS, và dẫn đường thật tới yêu cầu đã nhận.
class RescueMapScreen extends StatefulWidget {
  const RescueMapScreen({super.key});
  @override
  State<RescueMapScreen> createState() => _RescueMapScreenState();
}

class _RescueMapScreenState extends State<RescueMapScreen> {
  final _mapKey = GlobalKey<AppMapState>();
  MapTarget? _target;

  @override
  void initState() {
    super.initState();
    rescue.addListener(_refresh);
    navigateTo.addListener(_onNavigateRequest);
    _onNavigateRequest();
  }

  @override
  void dispose() {
    rescue.removeListener(_refresh);
    navigateTo.removeListener(_onNavigateRequest);
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Khi màn chi tiết bấm "Bắt đầu dẫn đường", nó đặt navigateTo rồi
  /// chuyển sang tab này; ở đây bắt lấy và vẽ lộ trình.
  void _onNavigateRequest() {
    final req = navigateTo.value;
    if (req == null) return;
    setState(() {
      _target = MapTarget(
        name: '${req.plate} · ${req.vehicleType}',
        subtitle: '${req.locationLabel} · ngập ${req.waterCm}cm',
        pos: req.pos,
      );
    });
  }

  /// Gom các yêu cầu chờ gần nhau (trong 600m) thành một điểm nóng.
  /// Trả về cụm đông nhất, hoặc rỗng nếu không có cụm nào từ 2 xe trở lên.
  List<SosRequest> get _hotspot {
    final waiting = rescue.waitingList;
    if (waiting.length < 2) return const [];

    List<SosRequest> best = const [];
    for (final seed in waiting) {
      final cluster = waiting.where((r) {
        final d = distanceKm(seed.pos.latitude, seed.pos.longitude, r.pos.latitude, r.pos.longitude);
        return d <= 0.6;
      }).toList();
      if (cluster.length > best.length) best = cluster;
    }
    return best.length >= 2 ? best : const [];
  }

  /// Điều xe tới điểm nóng: nhận yêu cầu khẩn nhất trong cụm rồi dẫn đường.
  void _dispatchToHotspot(List<SosRequest> cluster) {
    // Ưu tiên xe có người bên trong, sau đó tới xe ngập sâu nhất.
    final sorted = [...cluster]..sort((a, b) {
        if (a.personInside != b.personInside) return a.personInside ? -1 : 1;
        return b.waterCm.compareTo(a.waterCm);
      });
    final target = sorted.first;
    rescue.accept(target.id);
    navigateTo.value = target;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã nhận ${target.plateFull} — ưu tiên cao nhất trong khu vực'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Set<fm.Marker> _markers() {
    final markers = <fm.Marker>{
      const fm.Marker(
        point: rescueBase,
        width: 40,
        height: 40,
        child: Icon(Icons.home_repair_service, color: Colors.blue, size: 30),
      ),
    };

    for (final r in rescue.requests) {
      if (r.status == ReqStatus.dismissed || r.status == ReqStatus.done) continue;
      final color = r.personInside
          ? Colors.red
          : (r.status == ReqStatus.waiting ? Colors.orange : Colors.green);
      
      markers.add(fm.Marker(
        point: r.pos,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => RequestDetailScreen(id: r.id))),
          child: Icon(Icons.sos, color: color, size: 30),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final waiting = rescue.waitingList;
    final active = rescue.active;

    return AppMap(
      key: _mapKey,
      center: rescueBase,
      markers: _markers().toList(),
      target: _target,
      onClearTarget: () {
        navigateTo.value = null;
        setState(() => _target = null);
      },
      topOverlay: _filterChips(context, waiting.length, active == null ? 0 : 1),
      bottomOverlay: _requestList(context, waiting),
      sideButtons: _target == null
          ? [
              MapFab(
                icon: Icons.my_location,
                bg: C.surface(context),
                fg: C.brand(context),
                onTap: () => _mapKey.currentState?.moveTo(rescueBase),
              ),
            ]
          : const [],
    );
  }

  Widget _filterChips(BuildContext c, int waiting, int active) {
    return Row(children: [
      _chip(c, 'Chưa nhận · $waiting', true, () => _showList(c, rescue.waitingList, 'Yêu cầu chưa nhận')),
      const SizedBox(width: 8),
      _chip(c, 'Đang xử lý · $active', false, () {
        final a = rescue.active;
        _showList(c, a == null ? [] : [a], 'Đang xử lý');
      }),
    ]);
  }

  Widget _chip(BuildContext c, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: on ? C.brandBg(c) : C.surface(c),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: Text(label, style: T.small(c, on ? C.brand(c) : C.muted(c)).copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// Bấm chip hiện danh sách yêu cầu tương ứng.
  void _showList(BuildContext c, List<SosRequest> items, String title) {
    showModalBottomSheet(
      context: c,
      backgroundColor: C.surface(c),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(S.x4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: C.line(ctx), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text(title, style: T.title(ctx))),
              Text('${items.length} yêu cầu', style: T.small(ctx)),
            ]),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Không có yêu cầu nào', style: T.small(ctx)),
              )
            else
              for (final r in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _requestRow(ctx, r),
                ),
          ]),
        ),
      ),
    );
  }

  /// Thẻ điểm nóng — nhiều xe báo SOS cùng một khu vực trong thời gian ngắn.
  Widget _hotspotCard(BuildContext c, List<SosRequest> cluster) {
    final withPeople = cluster.where((r) => r.personInside).length;
    final deepest = cluster.map((r) => r.waterCm).reduce((a, b) => a > b ? a : b);
    final km = distanceKm(
        rescueBase.latitude, rescueBase.longitude, cluster.first.pos.latitude, cluster.first.pos.longitude);

    return Container(
      padding: const EdgeInsets.all(S.x4),
      decoration: BoxDecoration(
        color: C.surface(c),
        border: Border.all(color: C.danger(c), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 16)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: C.danger(c)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Điểm nóng · ${cluster.length} xe',
                style: T.title(c).copyWith(fontSize: 15, color: C.danger(c))),
          ),
          Text(formatDistance(km), style: T.mono(c, C.brand(c)).copyWith(fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        Text(cluster.first.areaName, style: T.body(c).copyWith(fontSize: 14)),
        const SizedBox(height: 3),
        Text(
          withPeople > 0
              ? 'Sâu nhất ${deepest}cm · $withPeople xe có người bên trong'
              : 'Sâu nhất ${deepest}cm · không có người trong xe',
          style: T.small(c, withPeople > 0 ? C.danger(c) : null),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: AppButton('Xem danh sách', tone: Tone.ghost, height: 46,
                onTap: () => _showList(c, cluster, 'Điểm nóng · ${cluster.length} xe')),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            flex: 2,
            child: AppButton('Điều xe tới khu vực này', tone: Tone.danger, height: 46,
                onTap: () => _dispatchToHotspot(cluster)),
          ),
        ]),
      ]),
    );
  }

  Widget _requestRow(BuildContext c, SosRequest r) {
    final km = distanceKm(rescueBase.latitude, rescueBase.longitude, r.pos.latitude, r.pos.longitude);
    return InkWell(
      onTap: () {
        Navigator.pop(c);
        Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(id: r.id)));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: r.personInside ? C.danger(c) : C.line(c)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.plate} · ${r.vehicleType}', style: T.body(c).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${r.locationLabel} · ngập ${r.waterCm}cm', style: T.small(c)),
              if (r.personInside) ...[
                const SizedBox(height: 4),
                StatusTag('CÓ NGƯỜI TRONG XE', fg: C.danger(c), bg: C.dangerBg(c)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Text(formatDistance(km), style: T.mono(c, C.brand(c)).copyWith(fontSize: 14)),
          Icon(Icons.chevron_right, size: 18, color: C.muted(c)),
        ]),
      ),
    );
  }

  Widget _requestList(BuildContext c, List<SosRequest> waiting) {
    final cluster = _hotspot;
    if (cluster.isNotEmpty) return _hotspotCard(c, cluster);
    if (waiting.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(S.x4),
        decoration: BoxDecoration(
          color: C.surface(c),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 16)],
        ),
        child: Text('Không còn yêu cầu chờ trong khu vực',
            textAlign: TextAlign.center, style: T.small(c)),
      );
    }
    final nearest = waiting.first;
    final km = distanceKm(rescueBase.latitude, rescueBase.longitude, nearest.pos.latitude, nearest.pos.longitude);
    return Container(
      padding: const EdgeInsets.all(S.x4),
      decoration: BoxDecoration(
        color: C.surface(c),
        border: Border.all(color: C.danger(c), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 16)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusTag('GẦN NHẤT', fg: C.danger(c), bg: C.dangerBg(c)),
          const Spacer(),
          Text(formatDistance(km), style: T.mono(c, C.brand(c)).copyWith(fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        Text('${nearest.plate} · ${nearest.vehicleType}', style: T.title(c).copyWith(fontSize: 15)),
        Text('${nearest.locationLabel} · ngập ${nearest.waterCm}cm', style: T.small(c)),
        const SizedBox(height: 12),
        AppButton('Xem chi tiết', height: 46,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => RequestDetailScreen(id: nearest.id)))),
      ]),
    );
  }
}
