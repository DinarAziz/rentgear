import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../domain/report.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String periodLabel(DateTime? month) => month == null ? 'Semua waktu' : '${_bulan[month.month - 1]} ${month.year}';

/// Laporan admin: jumlah transaksi, pendapatan, alat terlaris, dan pendapatan per toko. Bisa diunduh sebagai PDF.
class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: AsyncView<List<Rental>>(
        load: state.repo.allRentals,
        builder: (context, rentals) {
          final report = RentalReport(rentals, month: _month);
          return ReadableListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<DateTime?>(
                      isExpanded: true,
                      value: _month,
                      items: [
                        for (final m in [null, ...RentalReport.months(rentals)])
                          DropdownMenuItem(value: m, child: Text(periodLabel(m))),
                      ],
                      onChanged: (m) => setState(() => _month = m),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Unduh PDF'),
                    onPressed: () => Printing.layoutPdf(
                      name: 'Laporan RentGear ${periodLabel(_month)}.pdf',
                      onLayout: (format) => reportPdf(report, format),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, value) in _summary(report))
                    SizedBox(
                      width: 160,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 4),
                              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SectionTitle('Alat terlaris'),
              _rows(report.topGear.take(5).toList(), 'unit'),
              const SectionTitle('Pendapatan per toko'),
              _rows(report.byStore, 'unit'),
            ],
          );
        },
      ),
    );
  }

  Widget _rows(List<ReportRow> rows, String unit) => rows.isEmpty
      ? const Card(child: ListTile(title: Text('Belum ada sewa yang dibayar pada periode ini.')))
      : Card(
          child: Column(
            children: [
              for (final (i, row) in rows.indexed)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  title: Text(row.name),
                  subtitle: Text('${row.count} $unit disewa'),
                  trailing: Text(rupiah(row.revenue), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        );
}

List<(String, String)> _summary(RentalReport r) => [
      ('Total transaksi', '${r.total}'),
      ('Sudah dibayar', '${r.paid}'),
      ('Selesai', '${r.completed}'),
      ('Batal/ditolak/tidak diambil', '${r.failed}'),
      ('Kena denda terlambat', '${r.late}'),
      ('Pendapatan sewa', rupiah(r.rentRevenue)),
      ('Pendapatan denda', rupiah(r.fineRevenue)),
      ('Total pendapatan', rupiah(r.revenue)),
    ];

/// Laporan yang sama dalam bentuk PDF A4.
Future<Uint8List> reportPdf(RentalReport report, PdfPageFormat format) {
  pw.Widget table(String title, List<ReportRow> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 14),
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 6),
          rows.isEmpty
              ? pw.Text('Belum ada sewa yang dibayar pada periode ini.')
              : pw.TableHelper.fromTextArray(
                  headers: ['No', 'Nama', 'Unit', 'Pendapatan'],
                  data: [
                    for (final (i, r) in rows.indexed) ['${i + 1}', r.name, '${r.count}', rupiah(r.revenue)],
                  ],
                  cellAlignments: {2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
                ),
        ],
      );

  final doc = pw.Document(title: 'Laporan RentGear');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (_) => [
      pw.Text('Laporan Transaksi RentGear', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Periode: ${periodLabel(report.month)}'),
      pw.Text('Dibuat: ${DateTime.now().toString().substring(0, 16)}'),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Ringkasan', 'Nilai'],
        data: [for (final (k, v) in _summary(report)) [k, v]],
        cellAlignments: {1: pw.Alignment.centerRight},
      ),
      table('Alat terlaris', report.topGear.take(10).toList()),
      table('Pendapatan per toko', report.byStore),
      pw.SizedBox(height: 14),
      pw.Text(
        'Pendapatan = biaya sewa setelah diskon ditambah denda. Deposit tidak dihitung karena dikembalikan ke penyewa.',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ],
  ));
  return doc.save();
}
