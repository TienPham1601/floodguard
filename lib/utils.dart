import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mở ứng dụng gọi điện của máy với số cho trước.
/// Dùng cho nút gọi cứu hộ, gọi chủ xe, gọi 115.
Future<void> callPhone(BuildContext context, String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri(scheme: 'tel', path: digits);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _snack(context, 'Không mở được ứng dụng gọi điện');
  } catch (_) {
    if (context.mounted) _snack(context, 'Thiết bị này không hỗ trợ gọi điện');
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Khoảng cách đường chim bay giữa hai toạ độ, đơn vị km (công thức haversine).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371.0;
  double toRad(double deg) => deg * pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Hiển thị khoảng cách cho người đọc: dưới 1km thì dùng mét.
String formatDistance(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

/// Mở ứng dụng Google Maps với chỉ đường thật từ điểm này tới điểm kia.
/// Dùng khi người dùng muốn dẫn đường từng chặng có giọng nói.
Future<void> openGoogleMapsDirections(BuildContext context, dynamic origin, dynamic destination) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': '${origin.latitude},${origin.longitude}',
    'destination': '${destination.latitude},${destination.longitude}',
    'travelmode': 'driving',
  });
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _snack(context, 'Không mở được Google Maps');
  } catch (_) {
    if (context.mounted) _snack(context, 'Không mở được Google Maps');
  }
}
