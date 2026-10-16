import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale_transaction.dart';
import '../services/thermal_printer_service.dart';
import '../services/currency_service.dart';

class ReceiptView extends StatefulWidget {
  final SaleTransaction sale;
  final String shopName;
  final String shopPhone;
  final String shopAddress;

  const ReceiptView({
    Key? key,
    required this.sale,
    this.shopName = 'SmartShop',
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
  bool _isBluetoothOn = false;
  bool _isConnected = false;
  bool _isBusy = false;

  String get _currency => CurrencyService.symbol;

  // Narrow, receipt-style page format — mimics an 80mm thermal roll instead
  // of a full A4 sheet, so the generated PDF actually looks like a receipt.
  static final PdfPageFormat _receiptFormat = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 8 * PdfPageFormat.mm,
  );

  @override
  void initState() {
    super.initState();
    _refreshBluetoothState();
  }

  Future<void> _refreshBluetoothState() async {
    await _printerService.requestBluetoothPermissions();
    final isOn = await _printerService.isBluetoothOn();
    if (!mounted) return;

    setState(() => _isBluetoothOn = isOn);

    if (isOn) {
      await _loadBondedDevices();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bluetooth is off. Tap "Pair New Printer" to open settings and turn it on.',
          ),
        ),
      );
    }
  }

  Future<void> _loadBondedDevices() async {
    final list = await _printerService.getBondedDevices();
    final connected = await _printerService.isConnected();
    if (!mounted) return;
    setState(() {
      _devices = list;
      _isConnected = connected;
      if (_selectedDevice == null && _devices.isNotEmpty) {
        _selectedDevice = _devices.first;
      }
    });
  }

  Future<void> _connectToSelectedDevice() async {
    if (_selectedDevice == null) return;
    setState(() => _isBusy = true);
    try {
      await _printerService.connect(_selectedDevice!);
      if (!mounted) return;
      setState(() => _isConnected = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${_selectedDevice!.name ?? "printer"}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _printThermal() async {
    if (!_isBluetoothOn) {
      await _refreshBluetoothState();
      if (!_isBluetoothOn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please turn on Bluetooth to print.')),
        );
        return;
      }
    }

    if (_devices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No paired printer found. Tap "Pair New Printer" below.')),
      );
      return;
    }

    if (!_isConnected) {
      await _connectToSelectedDevice();
    }

    if (!_isConnected) return;

    setState(() => _isBusy = true);
    try {
      await _printerService.printReceiptForSale(
        widget.sale,
        widget.shopName,
        shopPhone: widget.shopPhone,
        shopAddress: widget.shopAddress,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt sent to printer!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pairNewPrinter() async {
    await _printerService.openSystemBluetoothSettings();
  }

  Future<void> _sharePdfReceipt() async {
    setState(() => _isBusy = true);
    try {
      final bytes = await _generatePdfReceipt(_receiptFormat);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/receipt_${widget.sale.id}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Receipt from ${widget.shopName}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share receipt: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
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
            tooltip: 'Share Receipt (PDF)',
            onPressed: _isBusy ? null : _sharePdfReceipt,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Thermal Receipt',
            onPressed: _isBusy ? null : _printThermal,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.indigo.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                      color: _isConnected ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      !_isBluetoothOn
                          ? 'Bluetooth is off'
                          : _devices.isEmpty
                              ? 'No paired printer found'
                              : _isConnected
                                  ? 'Connected: ${_selectedDevice?.name ?? ""}'
                                  : 'Printer selected (not connected)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_devices.isNotEmpty)
                  DropdownButton<bt.BluetoothDevice>(
                    value: _selectedDevice,
                    isExpanded: true,
                    items: _devices.map((device) {
                      return DropdownMenuItem(
                        value: device,
                        child: Text(device.name ?? 'Unknown Device'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDevice = val;
                        _isConnected = false;
                      });
                    },
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _isBusy ? null : _refreshBluetoothState,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                    TextButton.icon(
                      onPressed: _isBusy ? null : _pairNewPrinter,
                      icon: const Icon(Icons.bluetooth_searching, size: 16),
                      label: const Text('Pair New Printer'),
                    ),
                    if (_devices.isNotEmpty && !_isConnected)
                      TextButton.icon(
                        onPressed: _isBusy ? null : _connectToSelectedDevice,
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Connect'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (format) => _generatePdfReceipt(_receiptFormat),
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

    final dashedLine = pw.Container(
      width: double.infinity,
      child: pw.Row(
        children: List.generate(
          40,
          (i) => pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 0.5),
              height: 1,
              color: i.isEven ? PdfColors.grey600 : PdfColors.white,
            ),
          ),
        ),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // --- Shop header ---
              pw.Center(
                child: pw.Text(
                  widget.shopName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (widget.shopAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    widget.shopAddress,
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (widget.shopPhone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Tel: ${widget.shopPhone}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              pw.SizedBox(height: 4),
              dashedLine,
              pw.SizedBox(height: 4),

              // --- Sale meta info ---
              _metaRow('Receipt', widget.sale.id),
              _metaRow('Date', widget.sale.createdAt.toString().split('.')[0]),
              _metaRow('Payment', widget.sale.paymentMethod),
              if (widget.sale.customerName != null &&
                  widget.sale.customerName!.isNotEmpty)
                _metaRow('Customer', widget.sale.customerName!),
              if (widget.sale.customerPhone != null &&
                  widget.sale.customerPhone!.isNotEmpty)
                _metaRow('Phone', widget.sale.customerPhone!),
              if (widget.sale.mpesaCode.isNotEmpty)
                _metaRow('Ref Code', widget.sale.mpesaCode),

              pw.SizedBox(height: 4),
              dashedLine,
              pw.SizedBox(height: 4),

              // --- Items header ---
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Item',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Amt',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),

              // --- Items list ---
              ...widget.sale.items.map((item) {
                final lineTotal = (item.quantity * item.unitPrice).toStringAsFixed(0);
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text(
                          item.productName,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${item.quantity}',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          lineTotal,
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              dashedLine,
              pw.SizedBox(height: 6),

              // --- Total ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '$_currency ${widget.sale.totalAmount.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              dashedLine,
              pw.SizedBox(height: 8),

              // --- Footer ---
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with us!',
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Powered by SmartShop POS',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    final List<int> pdfData = await pdf.save();
    return Uint8List.fromList(pdfData);
  }

  // Small helper for the compact "Label: Value" meta rows at the top of the
  // receipt, used for Receipt ID, Date, Payment, Customer, etc.
  pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }
}
