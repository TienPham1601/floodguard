import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';
import '../../widgets/logo.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;

  void _login() async {
    if (_emailCtl.text.isEmpty || _passCtl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await FirebaseService.login(_emailCtl.text.trim(), _passCtl.text);
      // Khi login thành công, StreamBuilder trong main.dart sẽ tự động đổi home
      // Không cần điều hướng thủ công để tránh xung đột stack
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FloodGuardLogo(size: 90),
              const SizedBox(height: 24),
              Text('FloodGuard', style: T.h2(context).copyWith(fontSize: 32, color: C.brand(context))),
              const SizedBox(height: 8),
              Text('Hệ thống cảnh báo và cứu hộ ngập lụt', style: T.caption(context), textAlign: TextAlign.center),
              const SizedBox(height: 48),

              AppInput(label: 'Email', controller: _emailCtl, keyboardType: TextInputType.emailAddress, hint: 'Nhập email của bạn'),
              const SizedBox(height: 20),
              AppInput(
                label: 'Mật khẩu', 
                controller: _passCtl, 
                obscureText: !_showPassword,
                hint: '••••••••',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () {}, child: Text('Quên mật khẩu?', style: T.caption(context).copyWith(color: C.brand(context)))),
              ),
              const SizedBox(height: 32),

              _loading 
                ? const CircularProgressIndicator()
                : AppButton('Đăng nhập', height: 56, onTap: _login),
              
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text.rich(TextSpan(style: T.small(context), children: [
                  const TextSpan(text: 'Chưa có tài khoản? '),
                  TextSpan(text: 'Đăng ký ngay', style: TextStyle(color: C.brand(context), fontWeight: FontWeight.bold)),
                ])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
