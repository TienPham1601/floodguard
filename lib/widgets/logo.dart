import 'package:flutter/material.dart';

class FloodGuardLogo extends StatelessWidget {
  final double size;
  final Color? color;
  const FloodGuardLogo({super.key, this.size = 80, this.color});

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(themeColor),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;
  _LogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;

    // 1. Khiên bảo vệ
    final shieldPath = Path();
    shieldPath.moveTo(w * 0.5, 0);
    shieldPath.lineTo(w, h * 0.2);
    shieldPath.lineTo(w, h * 0.6);
    shieldPath.quadraticBezierTo(w, h * 0.9, w * 0.5, h);
    shieldPath.quadraticBezierTo(0, h * 0.9, 0, h * 0.6);
    shieldPath.lineTo(0, h * 0.2);
    shieldPath.close();
    
    // Đổ bóng khiên nhẹ
    canvas.drawPath(shieldPath, paint..color = color.withValues(alpha: 0.15));
    canvas.drawPath(shieldPath, paint..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.08);
    paint.style = PaintingStyle.fill;

    // 2. Sóng nước ở dưới khiên
    final wavePath = Path();
    wavePath.moveTo(w * 0.1, h * 0.65);
    wavePath.quadraticBezierTo(w * 0.3, h * 0.55, w * 0.5, h * 0.65);
    wavePath.quadraticBezierTo(w * 0.7, h * 0.75, w * 0.9, h * 0.65);
    wavePath.lineTo(w * 0.9, h * 0.8);
    wavePath.quadraticBezierTo(w * 0.5, h * 0.95, w * 0.1, h * 0.8);
    wavePath.close();
    canvas.drawPath(wavePath, paint..color = color.withValues(alpha: 0.3));

    // 3. Hình ô tô cách điệu ở giữa khiên
    final carPath = Path();
    carPath.moveTo(w * 0.25, h * 0.5);
    carPath.lineTo(w * 0.3, h * 0.4);
    carPath.lineTo(w * 0.7, h * 0.4);
    carPath.lineTo(w * 0.75, h * 0.5);
    carPath.quadraticBezierTo(w * 0.8, h * 0.5, w * 0.8, h * 0.55);
    carPath.lineTo(w * 0.2, h * 0.55);
    carPath.quadraticBezierTo(w * 0.2, h * 0.5, w * 0.25, h * 0.5);
    carPath.close();
    canvas.drawPath(carPath, paint..color = color);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
