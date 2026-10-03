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
    // User pairs in system settings, then returns here and taps Refresh.
  }

  // Shares the receipt as an actual PDF file via Android's native share
  // sheet. WhatsApp can be picked from there — the cashier then selects the
  // contact manually, since WhatsApp's link API cannot both pre-fill a
  // number and attach a file in one step.
  Future<void> _sharePdfReceipt() async {
    setState(() => _isBusy = true);
    try {
      final bytes = await _generatePdfReceipt(PdfPageFormat.a4);
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
                    fontSize: 22,
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
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  "Powered by SmartShop POS",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
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
}
