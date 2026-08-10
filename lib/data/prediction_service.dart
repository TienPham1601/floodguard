import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RiskZone {
  final LatLng center;
  final double riskLevel;
  final List<LatLng> bounds;
  RiskZone(this.center, this.riskLevel, this.bounds);
}

class HourlyRain {
  final int hour;
  final double amount;
  final double prob;
  HourlyRain({required this.hour, required this.amount, required this.prob});
}

class WeatherData {
  final double temp;
  final double precipitation;
  final double prob;
  final int code;
  final double elevation;
  final List<HourlyRain> hourly;

  WeatherData({
    required this.temp,
    required this.precipitation,
    required this.prob,
    required this.code,
    required this.elevation,
    this.hourly = const [],
  });

  String get summary {
    if (hourly.isEmpty) return 'Dữ liệu thời tiết đang cập nhật.';
    final maxRain = hourly.reduce((a, b) => a.amount > b.amount ? a : b);
    final totalRain = hourly.map((e) => e.amount).reduce((a, b) => a + b);
    if (totalRain > 20) return 'Mưa rất lớn (${totalRain.toStringAsFixed(1)}mm/6h) - Nguy cơ ngập diện rộng.';
    if (maxRain.amount > 10) return 'Mưa to lúc ${maxRain.hour}h (${maxRain.amount.toStringAsFixed(1)}mm) - Cảnh báo ngập.';
    return 'Thời tiết ổn định trong 6h tới.';
  }
}

class PredictionService {
  static final Map<String, double> _elevCache = {};
  static const double gridStep = 0.005;

  static Future<WeatherData?> getLiveWeather(LatLng pos) async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,precipitation,weather_code&hourly=precipitation,precipitation_probability&forecast_days=1&timezone=auto';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        final hourlyData = data['hourly'];
        final currentHour = DateTime.now().hour;
        
        final List<HourlyRain> rainList = [];
        for (int i = 0; i < 6; i++) {
          final idx = currentHour + i;
          if (idx < (hourlyData['precipitation'] as List).length) {
            rainList.add(HourlyRain(
              hour: idx % 24,
              amount: (hourlyData['precipitation'][idx] as num).toDouble(),
              prob: (hourlyData['precipitation_probability'][idx] as num).toDouble(),
            ));
          }
        }

        return WeatherData(
          temp: (current['temperature_2m'] as num).toDouble(),
          precipitation: (current['precipitation'] as num).toDouble(),
          prob: rainList.isEmpty ? 0 : (rainList.map((e) => e.prob).reduce((a, b) => a + b) / rainList.length),
          code: (current['weather_code'] as num).toInt(),
          elevation: (data['elevation'] as num).toDouble(),
          hourly: rainList,
        );
      }
    } catch (e) {
      dev.log('Weather API Error: $e');
    }
    return null;
  }

  static Future<List<RiskZone>> getRiskZonesFixed(
    LatLng southWest, 
    LatLng northEast
  ) async {
    double totalRain6h = 0;
    try {
      final centerLat = (southWest.latitude + northEast.latitude) / 2;
      final centerLon = (southWest.longitude + northEast.longitude) / 2;
      final rainRes = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$centerLat&longitude=$centerLon&hourly=precipitation&forecast_days=1'));
      if (rainRes.statusCode == 200) {
        final data = jsonDecode(rainRes.body);
        final List rain = data['hourly']['precipitation'];
        totalRain6h = rain.take(6).map((e) => (e as num).toDouble()).reduce((a, b) => a + b);
      }
    } catch (_) {}

    dev.log('PREDICTION_DEBUG: Total Rain Forecast 6h: ${totalRain6h.toStringAsFixed(1)}mm');

    final int startLatIdx = (southWest.latitude / gridStep).floor();
    final int endLatIdx = (northEast.latitude / gridStep).ceil();
    final int startLonIdx = (southWest.longitude / gridStep).floor();
    final int endLonIdx = (northEast.longitude / gridStep).ceil();

    final List<String> missingKeys = [];
    final List<LatLng> pointsToFetch = [];
    for (int i = startLatIdx; i <= endLatIdx; i++) {
      for (int j = startLonIdx; j <= endLonIdx; j++) {
        final key = '$i,$j';
        if (!_elevCache.containsKey(key)) {
          missingKeys.add(key);
          pointsToFetch.add(LatLng(i * gridStep + gridStep/2, j * gridStep + gridStep/2));
        }
        if (pointsToFetch.length >= 80) break;
      }
      if (pointsToFetch.length >= 80) break;
    }

    if (pointsToFetch.isNotEmpty) {
      try {
        final latsStr = pointsToFetch.map((p) => p.latitude).join(',');
        final lonsStr = pointsToFetch.map((p) => p.longitude).join(',');
        final elevRes = await http.get(Uri.parse(
            'https://api.open-meteo.com/v1/elevation?latitude=$latsStr&longitude=$lonsStr'));
        if (elevRes.statusCode == 200) {
          final elevData = jsonDecode(elevRes.body);
          final List<double> newElevs = (elevData['elevation'] as List).map((e) => (e as num).toDouble()).toList();
          for (int i = 0; i < pointsToFetch.length; i++) {
            _elevCache[missingKeys[i]] = newElevs[i];
          }
        }
      } catch (_) {}
    }

    final List<RiskZone> zones = [];
    double sumElev = 0;
    int countElev = 0;
    for (int i = startLatIdx; i <= endLatIdx; i++) {
      for (int j = startLonIdx; j <= endLonIdx; j++) {
        final key = '$i,$j';
        if (_elevCache.containsKey(key)) {
          sumElev += _elevCache[key]!;
          countElev++;
        }
      }
    }

    if (countElev == 0) return [];
    final avgElev = sumElev / countElev;

    for (int i = startLatIdx; i <= endLatIdx; i++) {
      for (int j = startLonIdx; j <= endLonIdx; j++) {
        final key = '$i,$j';
        if (_elevCache.containsKey(key)) {
          final elev = _elevCache[key]!;
          final diff = avgElev - elev;
          
          // LOGIC MỚI: Rủi ro = Mưa + Địa hình
          // Mưa > 20mm -> Rủi ro nền 0.6 (Cam)
          // Mưa > 40mm -> Rủi ro nền 0.8 (Đỏ)
          double rainRisk = (totalRain6h / 40.0).clamp(0.0, 0.85);
          double terrainBonus = diff > 1.2 ? (diff / 6.0).clamp(0.1, 0.3) : 0.0;
          
          double finalRisk = (rainRisk + terrainBonus).clamp(0.0, 1.0);

          // Chỉ tô màu nếu thực sự có rủi ro (>0.3)
          if (finalRisk > 0.3) {
            final double lat = i * gridStep;
            final double lon = j * gridStep;
            zones.add(RiskZone(
              LatLng(lat + gridStep/2, lon + gridStep/2),
              finalRisk,
              [LatLng(lat, lon), LatLng(lat + gridStep, lon), LatLng(lat + gridStep, lon + gridStep), LatLng(lat, lon + gridStep)]
            ));
          }
        }
      }
    }
    
    dev.log('PREDICTION_DEBUG: Found ${zones.length} risky zones');
    return zones;
  }
}
