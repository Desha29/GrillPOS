import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../settings/data/models/restaurant_info_model.dart';
import '../data/reports_repository.dart';
import '../../../core/di/dependency_injection.dart';

import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportDetailsScreen extends StatelessWidget {
  final ReportsSummary summary;
  final List<TopItem> topItems;
  final String reportTitle;
  final DateTime? from;
  final DateTime? to;

  const ReportDetailsScreen({
    super.key,
    required this.summary,
    required this.topItems,
    this.reportTitle = 'تقرير المبيعات التفصيلي',
    this.from,
    this.to,
  });

  Future<void> _handlePrint(BuildContext context, RestaurantInfo info) async {
    final pdf = await _generatePdf(info);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _handleShare(BuildContext context, RestaurantInfo info) async {
    final pdf = await _generatePdf(info);
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  Future<pw.Document> _generatePdf(RestaurantInfo info) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.amiriBold();
    final normalFont = await PdfGoogleFonts.amiriRegular();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: normalFont, bold: font),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(info.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(info.address, style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('Phone: ${info.phone}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Text('GrillPOS', style: pw.TextStyle(fontSize: 20, color: PdfColors.grey)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Text(reportTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('Period: ${_formatDateRange()}', style: const pw.TextStyle(fontSize: 12))),
          pw.SizedBox(height: 30),
          pw.Text('Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            data: [
              ['Metric', 'Value'],
              ['Revenue', '${summary.revenue.toStringAsFixed(2)} EGP'],
              ['Total Orders', '${summary.ordersCount}'],
              ['Avg Order', '${summary.avgOrder.toStringAsFixed(2)} EGP'],
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Text('Top Selling Items', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            data: [
              ['Rank', 'Name', 'Qty', 'Revenue'],
              ...List.generate(topItems.length, (i) {
                final it = topItems[i];
                return ['${i + 1}', it.name, '${it.qty}', '${it.revenue.toStringAsFixed(2)} EGP'];
              }),
            ],
          ),
          pw.Footer(
            trailing: pw.Text('Report Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    final info = getIt<SettingsCubit>().currentRestaurantInfo ??
        RestaurantInfo(
          name: 'GrillPOS',
          address: 'Alkhanka',
          phone: '01000000000',
          email: 'info@grillpos.com',
          vat: '000-000-000',
        );

    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      appBar: AppBar(
        title: Text(reportTitle, 
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: AppColors.surfaceDark,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          tooltip: 'رجوع',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white70),
            tooltip: 'مشاركة',
            onPressed: () => _handleShare(context, info),
          ),
          IconButton(
            icon: const Icon(Icons.print, color: AppColors.warmOrange, size: 22),
            tooltip: 'طباعة',
            onPressed: () => _handlePrint(context, info),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(info.address, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                        Text('هاتف: ${info.phone}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                        Text('البريد: ${info.email}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      ],
                    ),
                    if (info.logoPath != null && info.logoPath != '')
                      Opacity(
                        opacity: 0.8,
                        child: Image.asset(
                          info.logoPath!,
                          height: 70,
                          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, size: 50, color: Colors.black12),
                        ),
                      )
                    else 
                      const Icon(Icons.restaurant, size: 50, color: Colors.black12),
                  ],
                ),
                const SizedBox(height: 10),
                Text('الرقم الضريبي: ${info.vat}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.black26, thickness: 1.5),
                ),
                
                // Report Info
                Center(
                  child: Column(
                    children: [
                      Text(
                        reportTitle,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الفترة: ${_formatDateRange()}',
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Summary Section
                const Text(
                  'ملخص المبيعات الكلي',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: Colors.black12),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                  },
                  children: [
                    _buildSummaryRow('إجمالي المبيعات (Revenue)', '${summary.revenue.toStringAsFixed(2)} ج.م'),
                    _buildSummaryRow('عدد الطلبات (Total Orders)', '${summary.ordersCount}'),
                    _buildSummaryRow('متوسط قيمة الطلب (Average Order Value)', '${summary.avgOrder.toStringAsFixed(2)} ج.م'),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Top Items Section
                const Text(
                  'الأصناف الأكثر مبيعاً (Top Sellers)',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: Colors.black12),
                  columnWidths: const {
                    0: FlexColumnWidth(0.5),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1.2),
                  },
                  children: [
                    _buildTableHeader(['ت', 'الصنف', 'الكمية', 'الإجمالي']),
                    ...List.generate(topItems.length, (i) {
                      final item = topItems[i];
                      return _buildTableRow([
                        '${i + 1}',
                        item.name,
                        '${item.qty}',
                        '${item.revenue.toStringAsFixed(2)} ج.م'
                      ]);
                    }),
                  ],
                ),
                
                const SizedBox(height: 60),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تاريخ الإنشاء: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                            style: const TextStyle(color: Colors.black45, fontSize: 11)),
                        const Text('هذا التقرير تم إنشاؤه بواسطة نظام GrillPOS',
                            style: TextStyle(color: Colors.black45, fontSize: 10)),
                      ],
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 10),
                        Divider(color: Colors.black26),
                        Text('توقيع المدير المسؤول', style: TextStyle(color: Colors.black54, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                  const SizedBox(height: 40),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('رجوع للتقارير'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black54,
                      side: const BorderSide(color: Colors.black12),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateRange() {
    if (from == null && to == null) return 'الكل';
    final f = from != null ? DateFormat('yyyy-MM-dd').format(from!) : '...';
    final t = to != null ? DateFormat('yyyy-MM-dd').format(to!) : '...';
    return '$f إلى $t';
  }

  TableRow _buildSummaryRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.normal)),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(value, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ),
      ],
    );
  }

  TableRow _buildTableHeader(List<String> headers) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade100),
      children: headers.map((h) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(h, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
      )).toList(),
    );
  }

  TableRow _buildTableRow(List<String> cells) {
    return TableRow(
      children: cells.map((c) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(c, style: const TextStyle(color: Colors.black87, fontSize: 12), textAlign: TextAlign.center),
      )).toList(),
    );
  }
}
