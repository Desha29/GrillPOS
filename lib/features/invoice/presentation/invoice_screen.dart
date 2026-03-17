import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../../orders/data/order_models.dart';
import '../../../core/constants/app_colors.dart';

class InvoiceScreen extends StatelessWidget {
  final RestaurantOrder order;
  final String restaurantName;
  final String? restaurantPhone;
  final String? restaurantAddress;
  final String? restaurantLogo;

  const InvoiceScreen({
    super.key,
    required this.order,
    this.restaurantName = 'GrillPOS Restaurant',
    this.restaurantPhone,
    this.restaurantAddress,
    this.restaurantLogo,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            // Invoice Body
            Expanded(
              child: Center(
                child: Container(
                  width: 420,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (restaurantLogo != null && restaurantLogo!.isNotEmpty && File(restaurantLogo!).existsSync())
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Image.file(
                                File(restaurantLogo!),
                                height: 64,
                                width: 64,
                                fit: BoxFit.contain,
                              ),
                            ),
                          // Restaurant Name
                          Text(
                            restaurantName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1D24),
                            ),
                          ),
                          if (restaurantAddress != null &&
                              restaurantAddress!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                restaurantAddress!,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ),
                          if (restaurantPhone != null &&
                              restaurantPhone!.isNotEmpty)
                            Text(
                              restaurantPhone!,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          const Divider(height: 24),

                          // Invoice Info
                          _invoiceInfoRow(
                              'رقم الفاتورة', '#${order.orderNumber}'),
                          _invoiceInfoRow(
                              'التاريخ', dateFormat.format(order.createdAt)),
                          _invoiceInfoRow(
                              'الوقت', timeFormat.format(order.createdAt)),
                          _invoiceInfoRow(
                              'نوع الطلب', order.orderType.displayName),
                          if (order.tableId != null)
                            _invoiceInfoRow('الطاولة', order.tableId!),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Column labels
                          Row(
                            children: const [
                              Expanded(
                                  flex: 4,
                                  child: Text('الصنف',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1A1D24)))),
                              Expanded(
                                  flex: 1,
                                  child: Text('الكمية',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1A1D24)))),
                              Expanded(
                                  flex: 2,
                                  child: Text('السعر',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1A1D24)))),
                              Expanded(
                                  flex: 2,
                                  child: Text('الإجمالي',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1A1D24)))),
                            ],
                          ),
                          const Divider(),

                          // Items
                          ...order.items.map((item) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                        flex: 4,
                                        child: Text(item.itemName,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF333333)))),
                                    Expanded(
                                        flex: 1,
                                        child: Text('${item.quantity}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF333333)))),
                                    Expanded(
                                        flex: 2,
                                        child: Text(
                                            item.unitPrice.toStringAsFixed(2),
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF333333)))),
                                    Expanded(
                                        flex: 2,
                                        child: Text(
                                            item.subtotal.toStringAsFixed(2),
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF333333)))),
                                  ],
                                ),
                              )),

                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FC),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              children: [
                                _totalRow('المجموع الفرعي', order.subtotal),
                                _totalRow('الضريبة', order.tax),
                                if (order.discount > 0)
                                  _totalRow('الخصم', -order.discount),
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('الإجمالي',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1D24))),
                                    Text(
                                      '${order.totalAmount.toStringAsFixed(2)} ج.م',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF5722)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'شكراً لزيارتكم!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.charcoalMedium,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: AppColors.cream),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'فاتورة #${order.orderNumber}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cream,
                  ),
                ),
                Text(
                  order.orderType.displayName,
                  style: TextStyle(fontSize: 13, color: AppColors.creamMuted),
                ),
              ],
            ),
          ),
          // Print Button
          ElevatedButton.icon(
            onPressed: () => _printInvoice(context),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('طباعة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),
          // Share / PDF
          OutlinedButton.icon(
            onPressed: () => _shareAsPdf(context),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warmOrange,
              side: BorderSide(color: AppColors.warmOrange),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D24))),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text('${value.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333))),
        ],
      ),
    );
  }

  Future<void> _printInvoice(BuildContext context) async {
    final pdf = _buildPdf();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdf);
  }

  Future<void> _shareAsPdf(BuildContext context) async {
    final pdf = _buildPdf();
    await Printing.sharePdf(
        bytes: await pdf, filename: 'invoice_${order.orderNumber}.pdf');
  }

  Future<Uint8List> _buildPdf() async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );

    pw.MemoryImage? pdfLogo;
    if (restaurantLogo != null && restaurantLogo!.isNotEmpty) {
      final file = File(restaurantLogo!);
      if (file.existsSync()) {
        pdfLogo = pw.MemoryImage(file.readAsBytesSync());
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(8),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (pdfLogo != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Image(pdfLogo, height: 48, width: 48),
                ),
              pw.Text(restaurantName,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              if (restaurantAddress != null && restaurantAddress!.isNotEmpty)
                pw.Text(restaurantAddress!,
                    style: const pw.TextStyle(fontSize: 10)),
              if (restaurantPhone != null && restaurantPhone!.isNotEmpty)
                pw.Text(restaurantPhone!,
                    style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('#${order.orderNumber}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                      DateFormat('yyyy/MM/dd hh:mm a').format(order.createdAt),
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Text(order.orderType.displayName,
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              // Table header
              pw.Row(
                children: [
                  pw.Expanded(
                      flex: 4,
                      child: pw.Text('Item',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('Qty',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text('Total',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(),
              // Items
              ...order.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                            flex: 4,
                            child: pw.Text(item.itemName,
                                style: const pw.TextStyle(fontSize: 10))),
                        pw.Expanded(
                            flex: 1,
                            child: pw.Text('${item.quantity}',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 10))),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text(item.subtotal.toStringAsFixed(2),
                                textAlign: pw.TextAlign.right,
                                style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                  )),
              pw.Divider(),
              _pdfTotalRow('Subtotal', order.subtotal),
              _pdfTotalRow('Tax', order.tax),
              if (order.discount > 0) _pdfTotalRow('Discount', -order.discount),
              pw.Divider(thickness: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(order.totalAmount.toStringAsFixed(2),
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text('Thank you for your visit!',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfTotalRow(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value.toStringAsFixed(2),
              style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
