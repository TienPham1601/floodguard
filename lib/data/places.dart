import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class Place {
  final String name;
  final LatLng pos;
  final String address;
  final double distanceKm;

  Place({required this.name, required this.pos, required this.address, this.distanceKm = 0});
}

class SearchService {
  static Future<List<Place>> search(String query, {LatLng? userPos}) async {
    // 1. Dùng request Nominatim đơn giản, nới rộng để không bị rỗng
    // Giữ countrycodes=vn để ưu tiên Việt Nam nhưng không dùng viewbox/bounded khóa chặt
    final url = 'https://nominatim.openstreetmap.org/search?q=$query&format=json&countrycodes=vn&accept-language=vi&limit=10&addressdetails=1';
    
    try {
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'com.example.floodguard'});
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        List<Place> results = data.map((i) {
          final lat = double.parse(i['lat']);
          final lon = double.parse(i['lon']);
          final pos = LatLng(lat, lon);
          double dist = 0;
          if (userPos != null) {
            dist = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, lat, lon) / 1000;
          }

          // Tên chính và địa chỉ phụ
          String displayName = i['display_name'] ?? '';
          final parts = displayName.split(', ');
          final name = parts[0];
          
          // Lấy 2-3 phần tiếp theo làm địa chỉ phụ (Quận, Tỉnh...)
          String addr = parts.length > 1 ? parts.skip(1).take(3).join(', ') : '';

          return Place(
            name: name,
            pos: pos,
            address: addr,
            distanceKm: dist,
          );
        }).toList();

        // 2. Sắp xếp kết quả theo KHOẢNG CÁCH tới user (nếu có vị trí)
        if (userPos != null) {
          results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        }
        return results;
      }
    } catch (_) {}
    return [];
  }

  static Future<String> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=vi');
    try {
      final res = await http.get(url, headers: {'User-Agent': 'com.example.floodguard'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['display_name'] ?? 'Không xác định';
      }
    } catch (_) {}
    return 'Không xác định';
  }
}
