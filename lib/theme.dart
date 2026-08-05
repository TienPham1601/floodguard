import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ba mức trạng thái mực nước.
enum Level { safe, warn, danger }

Level levelOf(double cm, double warnAt, double dangerAt) {
  if (cm >= dangerAt) return Level.danger;
  if (cm >= warnAt) return Level.warn;
  return Level.safe;
}

/// Bảng màu. Mọi màu trong app phải lấy từ đây, không dùng Color(0x...) trực tiếp.
class C {
  static bool _d(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  static Color bg(BuildContext c) => _d(c) ? const Color(0xFF121212) : const Color(0xFFF1F5F9);
  static Color surface(BuildContext c) => _d(c) ? const Color(0xFF1E1E1E) : Colors.white;
  static Color line(BuildContext c) => _d(c) ? const Color(0xFF3A3A3A) : const Color(0xFFCBD5E1);
  static Color ink(BuildContext c) => _d(c) ? const Color(0xFFECEFF1) : const Color(0xFF0F172A);
  static Color muted(BuildContext c) => _d(c) ? const Color(0xFF9E9E9E) : const Color(0xFF64748B);

  static Color brand(BuildContext c) => _d(c) ? const Color(0xFF1E88E5) : const Color(0xFF1565C0);
  static Color brandBg(BuildContext c) => _d(c) ? const Color(0xFF0D2B4E) : const Color(0xFFE3F2FD);

  static Color safe(BuildContext c) => _d(c) ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
  static Color safeBg(BuildContext c) => _d(c) ? const Color(0xFF12301A) : const Color(0xFFE8F5E9);
  static Color warn(BuildContext c) => _d(c) ? const Color(0xFFFF9800) : const Color(0xFFF57F17);
  static Color warnBg(BuildContext c) => _d(c) ? const Color(0xFF3A2600) : const Color(0xFFFFF3E0);
  static Color danger(BuildContext c) => _d(c) ? const Color(0xFFF44336) : const Color(0xFFB71C1C);
  static Color dangerBg(BuildContext c) => _d(c) ? const Color(0xFF3A0F0F) : const Color(0xFFFFEBEE);

  // Marker điểm ngập trên bản đồ (không đổi theo dark mode)
  static const shallow = Color(0xFFF9A825);
  static const mid = Color(0xFFE65100);
  static const deep = Color(0xFFB71C1C);

  static Color of(BuildContext c, Level l) => switch (l) {
        Level.safe => safe(c),
        Level.warn => warn(c),
        Level.danger => danger(c),
      };

  static Color bgOf(BuildContext c, Level l) => switch (l) {
        Level.safe => safeBg(c),
        Level.warn => warnBg(c),
        Level.danger => dangerBg(c),
      };
}

/// Kiểu chữ. Không tạo TextStyle mới ở ngoài file này.
class T {
  static TextStyle big(BuildContext c, Color color) =>
      GoogleFonts.jetBrainsMono(fontSize: 64, fontWeight: FontWeight.w800, color: color, height: 1);
  static TextStyle sensor(BuildContext c, Color color) =>
      GoogleFonts.jetBrainsMono(fontSize: 38, fontWeight: FontWeight.w700, color: color, height: 1);
  static TextStyle mono(BuildContext c, [Color? color]) =>
      GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.w700, color: color ?? C.ink(c));
  static TextStyle monoSm(BuildContext c, [Color? color]) =>
      GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w500, color: color ?? C.muted(c));
  static TextStyle h2(BuildContext c) =>
      GoogleFonts.beVietnamPro(fontSize: 22, fontWeight: FontWeight.w700, color: C.ink(c));
  static TextStyle title(BuildContext c) =>
      GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w600, color: C.ink(c));
  static TextStyle body(BuildContext c, [Color? color]) =>
      GoogleFonts.beVietnamPro(fontSize: 15, color: color ?? C.ink(c), height: 1.5);
  static TextStyle small(BuildContext c, [Color? color]) =>
      GoogleFonts.beVietnamPro(fontSize: 13, color: color ?? C.muted(c));
  static TextStyle caption(BuildContext c, [Color? color]) =>
      GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500, color: color ?? C.muted(c), height: 1.5);
  static TextStyle label(BuildContext c, Color color) =>
      GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: color);
}

/// Khoảng cách. Chỉ dùng các số này.
class S {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
}

ThemeData appTheme(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    brightness: b,
    scaffoldBackgroundColor: dark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
    colorSchemeSeed: const Color(0xFF1565C0),
    useMaterial3: true,
  );
}
