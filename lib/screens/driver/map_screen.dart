import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../widgets/app_map.dart';
import '../../data/directions.dart';
import '../../data/places.dart';
import '../../data/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<AppMapState> _mapState = GlobalKey<AppMapState>();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  LatLng _center = const LatLng(21.0285, 105.8542);
  List<Place> _searchResults = [];
  MapTarget? _target;
  bool _isLoading = false;
  bool _isSearchFocused = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCurrentPos();
    _searchFocus.addListener(() {
      setState(() => _isSearchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPos() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) setState(() => _center = pos);
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(val);
    });
  }

  Future<void> _performSearch(String val) async {
    if (val.isEmpty) {
      setState(() { _searchResults = []; _isLoading = false; });
      return;
    }
    setState(() => _isLoading = true);
    final pos = await LocationService.getCurrentLocation();
    final results = await SearchService.search(val, userPos: pos);
    if (mounted) {
      setState(() { _searchResults = results; _isLoading = false; });
    }
  }

  void _selectPlace(Place p) {
    setState(() {
      _target = MapTarget(name: p.name, subtitle: p.address, pos: p.pos);
      _searchResults = [];
      _searchCtrl.text = p.name;
      _center = p.pos;
    });
    _mapState.currentState?.moveTo(p.pos);
    _searchFocus.unfocus();
  }

  void _showParkingNotice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: Icon(Icons.info_outline, color: Colors.blue.shade700, size: 32)),
            const SizedBox(height: 20),
            Text('Tính năng đang phát triển', style: T.title(ctx)),
            const SizedBox(height: 12),
            Text(
              'Hệ thống hiện dùng bản đồ mã nguồn mở miễn phí (OpenStreetMap) nên dữ liệu bãi đỗ tại Việt Nam còn hạn chế.\n\nChúng tôi sẽ sớm nâng cấp khi tích hợp dịch vụ bản đồ thương mại (Google Places) để tìm bãi đỗ an toàn hơn.',
              textAlign: TextAlign.center,
              style: T.body(ctx).copyWith(color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 24),
            AppButton('Đã hiểu', onTap: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearchActive = _isSearchFocused || _searchCtrl.text.isNotEmpty;

    return Scaffold(
      body: AppMap(
        key: _mapState,
        center: _center,
        markers: const [],
        target: _target,
        isSearchActive: isSearchActive,
        onClearTarget: () => setState(() { _target = null; _searchCtrl.clear(); _searchResults = []; }),
        topOverlay: Column(children: [
          _searchBar(),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_searchResults.isNotEmpty) _resultsList(),
          if (_searchResults.isEmpty && _searchCtrl.text.isNotEmpty && !_isLoading && _isSearchFocused) _noResults(),
        ]),
        sideButtons: [
          MapFab(icon: Icons.local_parking, bg: Colors.white, fg: Colors.blue.shade700, onTap: _showParkingNotice),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Tìm điểm đến...', 
          border: InputBorder.none, 
          prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
          suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _searchCtrl.clear(); _performSearch(''); }) : null,
        ),
      ),
    );
  }

  Widget _resultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 350),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length,
          separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (c, i) => ListTile(
            leading: Icon(Icons.location_on, color: Colors.blue.shade300, size: 20),
            title: Text(_searchResults[i].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(_searchResults[i].address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Text('${_searchResults[i].distanceKm.toStringAsFixed(1)}km', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            onTap: () => _selectPlace(_searchResults[i]),
          ),
        ),
      ),
    );
  }

  Widget _noResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: const Text('Không tìm thấy địa điểm nào.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }
}
