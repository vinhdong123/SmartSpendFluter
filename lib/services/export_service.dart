import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/utils/formatters.dart';
import '../models/report_models.dart';
import '../models/transaction_model.dart';

/// Xuất báo cáo ra PDF / Excel và chia sẻ qua ứng dụng khác.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  /// Tạo file. [persist] = true lưu vào thư mục tài liệu của ứng dụng, ngược lại dùng thư mục tạm.
  Future<File> build({
    required bool pdf,
    required String periodLabel,
    required int income,
    required int expense,
    required List<CategoryTotal> categories,
    required List<TransactionModel> transactions,
    required bool persist,
  }) async {
    final dir = persist
        ? Directory(p.join((await getApplicationDocumentsDirectory()).path, 'SmartSpend'))
        : await getTemporaryDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    final safe = periodLabel.replaceAll(RegExp(r'[^A-Za-z0-9À-ỹ]+'), '_');
    final file = File(p.join(dir.path, 'BaoCao_$safe.${pdf ? 'pdf' : 'xlsx'}'));
    final bytes = pdf
        ? await _pdf(periodLabel, income, expense, categories, transactions)
        : _excel(periodLabel, income, expense, categories, transactions);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> share(File file, String periodLabel) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Báo cáo chi tiêu SmartSpend – $periodLabel');
  }

  // ---------------- PDF ----------------

  Future<List<int>> _pdf(
    String period,
    int income,
    int expense,
    List<CategoryTotal> categories,
    List<TransactionModel> txs,
  ) async {
    // Font DejaVu có đủ dấu tiếng Việt (font mặc định của PDF thì không).
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    const primary = PdfColor.fromInt(0xFF0F766E);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
        ),
        build: (ctx) => [
          pw.Text('SmartSpend – Báo cáo chi tiêu',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primary)),
          pw.SizedBox(height: 4),
          pw.Text('Kỳ báo cáo: $period', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _box('Thu nhập', formatVND(income)),
            pw.SizedBox(width: 10),
            _box('Chi tiêu', formatVND(expense)),
            pw.SizedBox(width: 10),
            _box('Chênh lệch', formatVND(income - expense)),
          ]),
          pw.SizedBox(height: 18),
          pw.Text('Theo danh mục', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (categories.isEmpty)
            pw.Text('Không có dữ liệu.', style: const pw.TextStyle(fontSize: 10))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Danh mục', 'Số tiền', 'Tỷ lệ'],
              data: [
                for (final c in categories)
                  [
                    c.label,
                    formatVND(c.total),
                    '${(c.total * 100 / categories.fold<int>(0, (s, e) => s + e.total)).round()}%',
                  ],
              ],
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: primary),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
            ),
          pw.SizedBox(height: 18),
          pw.Text('Chi tiết giao dịch (${txs.length})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (txs.isEmpty)
            pw.Text('Không có giao dịch.', style: const pw.TextStyle(fontSize: 10))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Ngày', 'Danh mục', 'Ví', 'Ghi chú', 'Số tiền'],
              data: [
                for (final t in txs)
                  [formatDate(t.date), t.category, t.wallet, t.note ?? t.title, t.formattedAmount],
              ],
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: primary),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {4: pw.Alignment.centerRight},
            ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _box(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
    );
  }

  // ---------------- EXCEL ----------------

  List<int> _excel(
    String period,
    int income,
    int expense,
    List<CategoryTotal> categories,
    List<TransactionModel> txs,
  ) {
    final book = Excel.createExcel();
    final defaultName = book.getDefaultSheet() ?? 'Sheet1';
    book.rename(defaultName, 'Tổng quan');

    final summary = book['Tổng quan'];
    summary.appendRow([TextCellValue('SmartSpend – Báo cáo chi tiêu')]);
    summary.appendRow([TextCellValue('Kỳ báo cáo'), TextCellValue(period)]);
    summary.appendRow([TextCellValue('Thu nhập'), IntCellValue(income)]);
    summary.appendRow([TextCellValue('Chi tiêu'), IntCellValue(expense)]);
    summary.appendRow([TextCellValue('Chênh lệch'), IntCellValue(income - expense)]);
    summary.appendRow([TextCellValue('')]);
    summary.appendRow([TextCellValue('Danh mục'), TextCellValue('Số tiền (đ)')]);
    for (final c in categories) {
      summary.appendRow([TextCellValue(c.label), IntCellValue(c.total)]);
    }

    final detail = book['Giao dịch'];
    detail.appendRow([
      TextCellValue('Ngày'),
      TextCellValue('Loại'),
      TextCellValue('Danh mục'),
      TextCellValue('Ví'),
      TextCellValue('Số tiền (đ)'),
      TextCellValue('Ghi chú'),
    ]);
    for (final t in txs) {
      detail.appendRow([
        TextCellValue(formatDate(t.date)),
        TextCellValue(t.isExpense ? 'Chi tiêu' : 'Thu nhập'),
        TextCellValue(t.category),
        TextCellValue(t.wallet),
        IntCellValue(t.amount.round()),
        TextCellValue(t.note ?? t.title),
      ]);
    }
    return book.encode() ?? <int>[];
  }
}
