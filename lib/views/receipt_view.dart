import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptView extends StatelessWidget {
  final String storeName;
  final String transactionId;
  final List<Map<String, dynamic>> items;
  final double totalPrice;

  const ReceiptView({
    super.key,
    required this.storeName,
    required this.transactionId,
    required this.items,
    required this.totalPrice,
  });

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            cross: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  storeName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Transaction #: $transactionId'),
              pw.Divider(),
              pw.SizedBox(height: 10),
              // Fixed deprecated pw.Table.fromTextArray to pw.TableHelper.fromTextArray
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Qty', 'Price'],
                data: items.map((item) {
                  return [
                    item['name'].toString(),
                    item['quantity'].toString(),
                    '\$${item['price']}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '\$${totalPrice.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save outputs a Uint8List directly, matching FutureOr<Uint8List>
    final List<int> pdfData = await doc.save();
    return Uint8List.fromList(pdfData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Preview'),
      ),
      body: PdfPreview(
        // The build method signature requires FutureOr<Uint8List>
        build: (PdfPageFormat format) async {
          final Uint8List bytes = await _generatePdf(format);
          return bytes;
        },
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
