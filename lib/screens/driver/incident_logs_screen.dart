import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// Removed unused import: flutter_animate
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

  @override
  void initState() {
    super.initState();
    _loadVehicle();
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
              pw.Text('NHẬT KÝ SỰ CỐ AN TOÀN', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900)),
              pw.SizedBox(height: 8),
              pw.Text('Hệ thống bảo vệ xe FloodGuard', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
              pw.Divider(thickness: 2, color: PdfColors.blue800),
              pw.SizedBox(height: 20),
              
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('THÔNG TIN PHƯƠNG TIỆN', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Biển số: ${_vehicle?.plate ?? "---"}', style: pw.TextStyle(font: font, fontSize: 14)),
                  pw.Text('Dòng xe: ${_vehicle?.model ?? "---"}', style: pw.TextStyle(font: font, fontSize: 14)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('NGÀY XUẤT BÁO CÁO', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600)),
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
                  final date = (d['time'] as Timestamp).toDate();
                  return [
                    DateFormat('dd/MM HH:mm').format(date),
                    d['event'] ?? '',
                    d['detail'] ?? '',
                  ];
                }).toList(),
              ),
              
              pw.Spacer(),
              pw.Divider(),
              pw.Align(alignment: pw.Alignment.center, child: pw.Text('Báo cáo được trích xuất tự động từ hệ thống FloodGuard Safety.', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600))),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'FloodGuard_Incident_Log_${_vehicle?.plate}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_vehicle == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: C.bg(context),
      appBar: topBar(context, 'Nhật ký sự cố', left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.db.collection('vehicles').doc(_vehicle!.id).collection('incident_logs').orderBy('time', descending: true).snapshots(),
        builder: (context, snapshot) {
          final logs = snapshot.data?.docs ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          return Column(
            children: [
              Expanded(
                child: logs.isEmpty 
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('Chưa có sự cố nào được ghi nhận.', style: TextStyle(color: Colors.grey)),
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
    // Nhóm logs theo ngày
    Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (var l in logs) {
      final date = (l['time'] as Timestamp).toDate();
      final key = DateFormat('dd/MM/yyyy').format(date);
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(l);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final isToday = entry.key == DateFormat('dd/MM/yyyy').format(DateTime.now());
        final isYesterday = entry.key == DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 1)));
        final label = isToday ? 'HÔM NAY' : (isYesterday ? 'HÔM QUA · ${entry.key.substring(0, 5)}' : entry.key);

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
    final time = (d['time'] as Timestamp).toDate();
    final event = (d['event'] ?? 'Sự cố').toString().toLowerCase();
    final detail = d['detail'] ?? '';
    
    Color dotColor = Colors.blue;
    if (event.contains('nguy hiểm') || event.contains('danger') || event.contains('ngập')) {
      dotColor = Colors.red;
    } else if (event.contains('cảnh báo') || event.contains('warning')) {
      dotColor = Colors.orange;
    } else if (event.contains('thiết bị') || event.contains('kết nối') || event.contains('device')) {
      dotColor = Colors.blue;
    } else if (event.contains('an toàn') || event.contains('safe') || event.contains('bình thường')) {
      dotColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line(context), width: 0.5))),
      child: Row(children: [
        Container(
          width: 10, height: 10, 
          decoration: BoxDecoration(
            color: dotColor, 
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.3), blurRadius: 4)]
          )
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d['event'] ?? 'Sự cố', style: T.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(detail, style: T.caption(context)),
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
            Expanded(child: Text('Sự kiện an toàn được lưu 12 tháng và không xoá được, dùng làm bằng chứng bảo hiểm.', style: T.caption(context).copyWith(color: Colors.green.shade800))),
          ]),
        ),
        const SizedBox(height: 16),
        AppButton('Xuất nhật ký (PDF)', icon: Icons.picture_as_pdf, tone: Tone.ghost, height: 48, onTap: logs.isEmpty ? null : () => _exportPDF(logs)),
      ]),
    );
  }
}
