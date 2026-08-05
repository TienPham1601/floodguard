import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _garageCtrl = TextEditingController();
  
  String _role = 'driver';
  bool _loading = false;

  void _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final garageCode = _garageCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseService.register(
        email: email, password: pass, fullName: name, phone: phone,
        role: _role, garageCode: _role == 'rescuer' ? garageCode : null,
      );
      // Đăng ký thành công -> Firebase tự động login -> authStateChanges emit
      // Chúng ta sẽ pop màn hình này để quay lại LoginScreen (hoặc main home sẽ thay đổi dưới nền)
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thành công! Đang đăng nhập...'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg(context),
      appBar: AppBar(title: const Text('Đăng ký tài khoản'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Bạn là ai?', style: T.title(context)),
          const SizedBox(height: 16),
          Row(children: [
            _roleCard('driver', 'Người lái xe', Icons.directions_car),
            const SizedBox(width: 12),
            _roleCard('rescuer', 'Thợ cứu hộ', Icons.build_circle),
          ]),
          const SizedBox(height: 32),
          AppInput(label: 'Họ và tên', controller: _nameCtrl),
          const SizedBox(height: 16),
          AppInput(label: 'Số điện thoại', controller: _phoneCtrl, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          AppInput(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          AppInput(label: 'Mật khẩu', controller: _passCtrl, obscureText: true),
          
          if (_role == 'rescuer') ...[
            const SizedBox(height: 16),
            AppInput(label: 'Mã đơn vị / Gara', controller: _garageCtrl, hint: 'Nhập mã được cấp cho gara'),
            const SizedBox(height: 8),
            Text('Thợ cứu hộ cần mã xác minh từ đơn vị quản lý để đăng ký.', style: T.caption(context)),
          ],
          
          const SizedBox(height: 40),
          _loading 
            ? const Center(child: CircularProgressIndicator())
            : AppButton('Tạo tài khoản', onTap: _submit),
        ],
      ),
    );
  }

  Widget _roleCard(String r, String label, IconData icon) {
    final active = _role == r;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = r),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: active ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? Colors.blue : Colors.grey.shade200, width: 2),
          ),
          child: Column(children: [
            Icon(icon, color: active ? Colors.blue : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: active ? Colors.blue : Colors.grey, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}
