import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme.dart';
import '../../ui.dart';
import '../../data/firebase_service.dart';

class VehicleDetailScreen extends StatefulWidget {
  final String vehicleId;
  final String plate;
  final String model;

  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
    required this.plate,
    required this.model,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Future<void> _exportLogPDF(Map<String, dynamic> vehicleData, List<QueryDocumentSnapshot> logs) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, text: 'NHẬT KÝ AN TOÀN FloodGuard'),
              pw.SizedBox(height: 20),
              pw.Text('Phương tiện: ${widget.model} (${widget.plate})'),
              pw.Text('Chủ sở hữu: ${FirebaseService.auth.currentUser?.email}'),
              pw.Text('Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 30),
              pw.TableHelper.fromTextArray(
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
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'FloodGuard_Log_${widget.plate}.pdf');
  }

  void _showThresholds(Map<String, dynamic> data) {
    double warn = (data['warnAt'] as num?)?.toDouble() ?? 20;
    double danger = (data['dangerAt'] as num?)?.toDouble() ?? 35;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cài đặt ngưỡng an toàn', style: T.title(ctx)),
            const SizedBox(height: 20),
            Text('Mực nước cảnh báo: ${warn.toStringAsFixed(0)} cm', style: T.small(ctx)),
            Slider(value: warn, min: 5, max: 40, onChanged: (v) => setS(() => warn = v)),
            Text('Mực nước nguy hiểm: ${danger.toStringAsFixed(0)} cm', style: T.small(ctx)),
            Slider(value: danger, min: 10, max: 60, onChanged: (v) => setS(() => danger = v)),
            const SizedBox(height: 24),
            AppButton('Lưu cài đặt', onTap: () {
              FirebaseFirestore.instance.collection('vehicles').doc(widget.vehicleId).update({
                'warnAt': warn,
                'dangerAt': danger,
              });
              Navigator.pop(ctx);
            }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      bar: topBar(context, widget.plate,
          left: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('vehicles').doc(widget.vehicleId).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (data == null) return const Center(child: CircularProgressIndicator());

          final type = data['type'] ?? 'Sedan';
          final warn = data['warnAt'] ?? 20;

          return ListView(
            padding: const EdgeInsets.all(S.x4),
            children: [
              AppCard(
                child: Row(children: [
                  VehicleIcon(type: type, width: 64, height: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.plate, style: T.mono(context).copyWith(fontSize: 19)),
                      Text('${widget.model} · $type', style: T.small(context)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: S.x4),

              _label(context, 'THÔNG SỐ VÀ NGƯỠNG'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(children: [
                  _kv(context, 'Loại xe', type),
                  _kv(context, 'Ngưỡng cảnh báo', '$warn cm'),
                  _kv(context, 'Ngưỡng nguy hiểm', '${data['dangerAt'] ?? 35} cm', last: true),
                ]),
              ),
              const SizedBox(height: 12),
              AppButton('Điều chỉnh ngưỡng', tone: Tone.soft, height: 44, onTap: () => _showThresholds(data)),
              const SizedBox(height: 32),

              _label(context, 'NHẬT KÝ SỰ CỐ'),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('vehicles').doc(widget.vehicleId).collection('incident_logs').orderBy('time', descending: true).limit(20).snapshots(),
                builder: (c, logSnap) {
                  final logs = logSnap.data?.docs ?? [];
                  if (logs.isEmpty) {
                    return AppCard(
                      child: Center(child: Text('Chưa có sự cố nào được ghi nhận.', style: T.caption(context))),
                    );
                  }
                  return Column(children: [
                    ...logs.map((l) {
                      final ld = l.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Icon(Icons.history, size: 16, color: C.muted(context)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(ld['event'] ?? 'Sự cố', style: T.small(context).copyWith(fontWeight: FontWeight.bold)),
                              Text(ld['detail'] ?? '', style: T.caption(context)),
                            ])),
                            Text(DateFormat('HH:mm').format((ld['time'] as Timestamp).toDate()), style: T.caption(context)),
                          ]),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    AppButton('Xuất báo cáo PDF', icon: Icons.picture_as_pdf, tone: Tone.soft, onTap: () => _exportLogPDF(data, logs)),
                  ]);
                }
              ),

              const SizedBox(height: 40),
              AppButton('Xóa xe khỏi hệ thống', tone: Tone.ghost, onTap: () => _deleteVehicle(context)),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  void _deleteVehicle(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa xe này khỏi hệ thống?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quay lại')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    if (confirm == true) {
      await FirebaseService.deleteVehicle(widget.vehicleId);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _label(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t, style: T.caption(c).copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      );

  Widget _kv(BuildContext c, String k, String v, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: C.line(c)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: T.small(c)),
          Text(v, style: T.body(c).copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      );
}
