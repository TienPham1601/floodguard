import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.surface(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: const FloodGuardLogo(size: 100),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fade,
              child: Column(children: [
                Text('FloodGuard', style: T.h2(context).copyWith(fontSize: 28, letterSpacing: 1.5, color: C.brand(context))),
                const SizedBox(height: 8),
                Text('BẢO VỆ XE KHỎI NGẬP LỤT', style: T.caption(context).copyWith(letterSpacing: 2, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
