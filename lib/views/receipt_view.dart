import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;
import 'package:url_launcher/url_launcher.dart';
import '../models/sale_transaction.dart';
import '../services/thermal_printer_service.dart';

class ReceiptView extends StatefulWidget {
  final SaleTransaction sale;
  final String shopName;
  final String shopPhone;
  final String shopAddress;

  const ReceiptView({
    Key? key,
    required this.sale,
    this.shopName = 'SMARTSHOP POS',
    this.shopPhone = '',
    this.shopAddress = '',
  }) : super(key: key);

  @override
  _ReceiptViewState createState() => _ReceiptViewState();
}

class _ReceiptViewState extends State<ReceiptView> {
  final ThermalPrinterService _printerService = ThermalPrinterService();
  List<bt.BluetoothDevice> _devices = [];
  bt.BluetoothDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _loadBluetoothDevices();
  }

  void _loadBluetoothDevices() async {
    List<bt.BluetoothDevice> list = await _printerService.getBondedDevices();
    if (!mounted) return;
    setState(() {
      _devices = list;
      if (_devices.isNotEmpty) _selectedDevice = _devices.first;
    });
  }

  Future<void> _printThermal() async {
    if (_selectedDevice != null) {
      await _printerService.printTextSample(
        widget.shopName,
        "Total: KES ${widget.sale.totalAmount.toStringAsFixed(0)}",
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt sent to printer!')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Bluetooth printer selected.')),
      );
    }
  }

  Future<void> _sendWhatsAppReceipt() async {
    String? phone = widget.sale.customerPhone;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No customer phone number available for this sale.'),
        ),
      );
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '254${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln("*${widget.shopName.toUpperCase()}*");
    if (widget.shopAddress.isNotEmpty) buffer.writeln(widget.shopAddress);
    if (widget.shopPhone.isNotEmpty) buffer.writeln("Tel: ${widget.shopPhone}");
    buffer.writeln("--------------------------------");
    buffer.writeln("Receipt ID: ${widget.sale.id}");
    buffer.writeln("Date: ${widget.sale.createdAt.toString().split('.')[0]}");
    buffer.writeln("Payment Method: ${widget.sale.paymentMethod}");
    if (widget.sale.mpesaCode.isNotEmpty) {
      buffer.writeln("M-Pesa Code: ${widget.sale.mpesaCode}");
    }
    buffer.writeln("--------------------------------");
    buffer.writeln("*ITEMS PURCHASED:*");
    for (var item in widget.sale.items) {
      buffer.writeln(
        "• ${item.productName} x${item.quantity} - KES ${(item.quantity * item.unitPrice).toStringAsFixed(0)}",
      );
    }
    buffer.writeln("--------------------------------");
    buffer.writeln(
      "*TOTAL: KES ${widget.sale.totalAmount.toStringAsFixed(0)}*",
    );
    buffer.writeln("\nThank you for shopping with us!");

    final uri = Uri.parse(
      "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(buffer.toString())}",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Receipt'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Send via WhatsApp',
            onPressed: _sendWhatsAppReceipt,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Thermal Receipt',
            onPressed: _printThermal,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_devices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Text("Printer: "),
                  Expanded(
                    child: DropdownButton<bt.BluetoothDevice>(
                      value: _selectedDevice,
                      items: _devices.map((device) {
                        return DropdownMenuItem(
                          value: device,
                          child: Text(device.name ?? 'Unknown Device'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedDevice = val),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PdfPreview(
              build: (format) => _generatePdfReceipt(format),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _generatePdfReceipt(PdfPageFormat format) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  widget.shopName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (widget.shopAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    widget.shopAddress,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              if (widget.shopPhone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    "Tel: ${widget.shopPhone}",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              pw.Center(child: pw.Text("Official Purchase Receipt")),
              pw.Divider(),
              pw.Text("Receipt ID: ${widget.sale.id}"),
              pw.Text("Date: ${widget.sale.createdAt.toString().split('.')[0]}"),
              pw.Text("Payment Mode: ${widget.sale.paymentMethod}"),
              if (widget.sale.customerName != null &&
                  widget.sale.customerName!.isNotEmpty)
                pw.Text("Customer: ${widget.sale.customerName}"),
              if (widget.sale.customerPhone != null &&
                  widget.sale.customerPhone!.isNotEmpty)
                pw.Text("Phone: ${widget.sale.customerPhone}"),
              if (widget.sale.mpesaCode.isNotEmpty)
                pw.Text("M-Pesa Code: ${widget.sale.mpesaCode}"),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Qty', 'Unit (KES)', 'Total (KES)'],
                data: widget.sale.items.map((item) {
                  return [
                    item.productName,
                    item.quantity.toString(),
                    item.unitPrice.toStringAsFixed(0),
                    (item.quantity * item.unitPrice).toStringAsFixed(0),
                  ];
                }).toList(),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "TOTAL AMOUNT:",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    "KES ${widget.sale.totalAmount.toStringAsFixed(0)}",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text("Thank you for shopping with us!")),
            ],
          );
        },
      ),
    );

    final List<int> pdfData = await pdf.save();
    return Uint8List.fromList(pdfData);
  }
}
