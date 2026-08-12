import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';

class IncidentLogsScreen extends StatefulWidget {
  const IncidentLogsScreen({super.key});

  @override
  State<IncidentLogsScreen> createState() => _IncidentLogsScreenState();
}

class _IncidentLogsScreenState extends State<IncidentLogsScreen> {
  VehicleData? _vehicle;
  late Stream<QuerySnapshot> _logStream;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
    final uid = FirebaseService.auth.currentUser?.uid;
    _logStream = FirebaseService.db.collection('incident_logs')
        .where('ownerId', isEqualTo: uid)
        .snapshots();
  }

  Future<void> _loadVehicle() async {
    final v = await FirebaseService.streamCurrentVehicle().first;
    if (mounted) setState(() => _vehicle = v);
  }

  Future<void> _exportPDF(List<QueryDocumentSnapshot> logs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.beVietnamProRegular();
    final fontBold = await PdfGoogleFonts.beVietnamProBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('NHẬT KÝ HOẠT ĐỘNG AN TOÀN', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900)),
              pw.SizedBox(height: 8),
              pw.Text('Hệ thống FloodGuard Safety System', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
              pw.Divider(thickness: 2, color: PdfColors.blue800),
              pw.SizedBox(height: 20),
              
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('CHỦ PHƯƠNG TIỆN', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Biển số: ${_vehicle?.plate ?? "---"}', style: pw.TextStyle(font: font, fontSize: 14)),
                  pw.Text('Dòng xe: ${_vehicle?.model ?? "---"}', style: pw.TextStyle(font: font, fontSize: 14)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('NGÀY TRÍCH XUẤT', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: pw.TextStyle(font: font, fontSize: 14)),
                ]),
              ]),
              
              pw.SizedBox(height: 30),
              pw.TableHelper.fromTextArray(
                context: context,
                border: null,
                headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: pw.TextStyle(font: font),
                headers: ['Thời gian', 'Sự kiện', 'Chi tiết'],
                data: logs.map((l) {
                  final d = l.data() as Map<String, dynamic>;
                  final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  return [
                    DateFormat('dd/MM HH:mm').format(date),
                    _getEventName(d['status'] ?? ''),
                    d['message'] ?? '',
                  ];
                }).toList(),
              ),
              
              pw.Spacer(),
              pw.Divider(),
              pw.Align(alignment: pw.Alignment.center, child: pw.Text('Báo cáo này có giá trị làm bằng chứng khi giám định bảo hiểm.', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600))),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'FloodGuard_Log_${_vehicle?.plate}.pdf');
  }

  static String _getEventName(String status) {
    switch (status) {
      case 'pending': return 'Gửi yêu cầu SOS';
      case 'accepted': return 'Tiếp nhận cứu hộ';
      case 'processing': return 'Đang di chuyển';
      case 'arrived': return 'Đã tới hiện trường';
      case 'done': return 'Hoàn tất cứu hộ';
      case 'timeout': return 'Yêu cầu hết hạn';
      case 'cancelled': return 'Hủy yêu cầu';
      case 'report': return 'Báo cáo điểm ngập';
      default: return 'Hoạt động';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService.auth.currentUser?.uid;
    return Scaffold(
      backgroundColor: C.bg(context),
      appBar: topBar(context, 'Nhật ký hoạt động', left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: StreamBuilder<QuerySnapshot>(
        stream: _logStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('LOG_SCREEN ERROR: ${snapshot.error}');
            return Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Không thể tải nhật ký. Vui lòng kiểm tra kết nối mạng hoặc thử lại sau.', textAlign: TextAlign.center, style: T.body(context, Colors.red)),
            ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          // SẮP XẾP PHÍA CLIENT ĐỂ TRÁNH LỖI INDEX FIRESTORE
          final List<QueryDocumentSnapshot> logs = (snapshot.data?.docs ?? []).toList();
          logs.sort((a, b) {
            final t1 = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final t2 = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (t1 == null || t2 == null) return 0;
            return t2.compareTo(t1); // Giảm dần
          });
          
          debugPrint('LOG_SCREEN: uid=$uid docs=${logs.length}');

          return Column(
            children: [
              Expanded(
                child: logs.isEmpty 
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      const Text('Chưa có hoạt động nào được ghi nhận.', style: TextStyle(color: Colors.grey)),
                    ]))
                  : _buildLogList(logs),
              ),
              _bottomActions(logs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogList(List<QueryDocumentSnapshot> logs) {
    Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (var l in logs) {
      final date = (l['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final key = DateFormat('dd/MM/yyyy').format(date);
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(l);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final isToday = entry.key == DateFormat('dd/MM/yyyy').format(DateTime.now());
        final isYesterday = entry.key == DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 1)));
        final label = isToday ? 'HÔM NAY' : (isYesterday ? 'HÔM QUA' : entry.key);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
            child: Text(label, style: T.caption(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: entry.value.map((l) => _logItem(l)).toList()),
          ),
        ]);
      }).toList(),
    );
  }

  Widget _logItem(QueryDocumentSnapshot l) {
    final d = l.data() as Map<String, dynamic>;
    final time = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = (d['status'] ?? '').toString();
    final message = d['message'] ?? '';
    
    Color dotColor = Colors.blue;
    if (['pending', 'danger'].contains(status)) {
      dotColor = Colors.red;
    } else if (['accepted', 'processing', 'warning'].contains(status)) {
      dotColor = Colors.blue;
    } else if (['done', 'safe'].contains(status)) {
      dotColor = Colors.green;
    } else if (['timeout', 'cancelled'].contains(status)) {
      dotColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line(context), width: 0.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 10, height: 10, 
            decoration: BoxDecoration(
              color: dotColor, 
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.3), blurRadius: 4)]
            )
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_getEventName(status), style: T.body(context).copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(message, style: T.caption(context).copyWith(height: 1.3)),
          if (d['vehiclePlate'] != null) 
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Xe: ${d['vehiclePlate']}', style: T.small(context, Colors.grey).copyWith(fontSize: 10)),
            ),
        ])),
        Text(DateFormat('HH:mm').format(time), style: T.caption(context)),
      ]),
    );
  }

  Widget _bottomActions(List<QueryDocumentSnapshot> logs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: C.surface(context), border: Border(top: BorderSide(color: C.line(context)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, size: 18, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(child: Text('Nhật ký được lưu trữ làm bằng chứng phục vụ yêu cầu bồi thường bảo hiểm.', style: T.caption(context).copyWith(color: Colors.green.shade800))),
          ]),
        ),
        const SizedBox(height: 16),
        AppButton('Xuất báo cáo (PDF)', icon: Icons.picture_as_pdf, tone: Tone.ghost, height: 48, onTap: logs.isEmpty ? null : () => _exportPDF(logs)),
      ]),
    );
  }
}
