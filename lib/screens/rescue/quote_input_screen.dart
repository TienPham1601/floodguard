import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';

class QuoteInputScreen extends StatefulWidget {
  final SOSRequest req;
  final String distText;
  final String timeText;

  const QuoteInputScreen({
    super.key,
    required this.req,
    required this.distText,
    required this.timeText,
  });

  @override
  State<QuoteInputScreen> createState() => _QuoteInputScreenState();
}

class _QuoteInputScreenState extends State<QuoteInputScreen> {
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  int? _selectedQuickPrice;

  final currencyFormat = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_formatPrice);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _formatPrice() {
    String text = _priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return;
    String formatted = currencyFormat.format(int.parse(text));
    if (_priceCtrl.text != formatted) {
      _priceCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _setQuickPrice(int price) {
    setState(() {
      _selectedQuickPrice = price;
      _priceCtrl.text = price.toString();
    });
  }

  void _submit() async {
    final priceStr = _priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (priceStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập giá dịch vụ.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseService.sendQuote(
        sosId: widget.req.id,
        price: int.parse(priceStr),
        note: _noteCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi báo giá. Đang đợi khách hàng xác nhận...'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg(context),
      appBar: topBar(context, 'Báo giá dịch vụ', left: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Card tóm tắt đơn (Việc 2)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.location_on, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${widget.req.vehicleModel} · ${widget.req.vehiclePlate}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Cách bạn ${widget.distText} · ETA ${widget.timeText}', style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
              ])),
            ]),
          ),
          const SizedBox(height: 32),

          Text('GIÁ DỊCH VỤ DỰ KIẾN', style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 16),
          
          // Ô nhập giá font lớn (Việc 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line(context))),
            child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.blue),
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: 'đ',
                suffixStyle: TextStyle(fontSize: 24, color: Colors.grey, fontWeight: FontWeight.bold),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Gợi ý nhanh (Việc 2)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _priceChip(300000, '300k'),
              _priceChip(500000, '500k'),
              _priceChip(800000, '800k'),
              _priceChip(1000000, '1tr'),
              _priceChip(1500000, '1.5tr'),
            ]),
          ),

          const SizedBox(height: 40),
          Text('GHI CHÚ (KHÔNG BẮT BUỘC)', style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Vd: Bao gồm phí kéo xe về Gara...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.line(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.line(context))),
            ),
          ),
          const SizedBox(height: 48),
          
          _loading 
            ? const Center(child: CircularProgressIndicator())
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade900]),
                  boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: AppButton(
                  'GỬI BÁO GIÁ NGAY', 
                  height: 64, 
                  tone: Tone.brand, // Background transparent because we use container gradient
                  onTap: _submit
                ),
              ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Text('Thông tin của bạn chỉ hiện khi khách đồng ý.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ],
      ),
    );
  }

  Widget _priceChip(int value, String label) {
    bool isSelected = _selectedQuickPrice == value;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.blue.shade700, fontWeight: FontWeight.bold)),
        selected: isSelected,
        onSelected: (val) => _setQuickPrice(value),
        selectedColor: Colors.blue.shade700,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.blue.shade700 : Colors.blue.shade100)),
        showCheckmark: false,
      ),
    );
  }
}
