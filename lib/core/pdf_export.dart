import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const _primary = PdfColor.fromInt(0xFF5B3CDD);
const _muted = PdfColor.fromInt(0xFF484555);
const _wash = PdfColor.fromInt(0xFFF7F1FF);

pw.Widget _header(String title, String subtitle) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('VitalU', style: pw.TextStyle(color: _primary, fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Text(subtitle, style: const pw.TextStyle(color: _muted, fontSize: 10)),
      pw.SizedBox(height: 14),
    ]);

pw.Widget _section(String title, List<List<String>> rows) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _wash, borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        for (final r in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Text(r[0], style: const pw.TextStyle(fontSize: 10))),
              pw.Text(r.length > 1 ? r[1] : '', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
      ]),
    );

Future<Uint8List> buildPdf({required String title, required String subtitle, required Map<String, List<List<String>>> sections, String? footer}) async {
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (ctx) => [
      _header(title, subtitle),
      for (final e in sections.entries) _section(e.key, e.value),
      if (footer != null) pw.Padding(padding: const pw.EdgeInsets.only(top: 8), child: pw.Text(footer, style: const pw.TextStyle(color: _muted, fontSize: 9))),
    ],
  ));
  return doc.save();
}

Future<void> sharePdf({required String title, required String subtitle, required Map<String, List<List<String>>> sections, String? footer, required String filename}) async {
  final bytes = await buildPdf(title: title, subtitle: subtitle, sections: sections, footer: footer);
  await Printing.sharePdf(bytes: bytes, filename: filename);
}

String pdfDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
