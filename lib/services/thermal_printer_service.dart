import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../models/sale_transaction.dart';

class ThermalPrinterService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  Future<bool> isConnected() async {
    return (await _bluetooth.isConnected) ?? false;
  }

  /// Requests the Android 12+ Bluetooth runtime permissions needed to scan
  /// and connect. Safe no-op on older Android versions.
  Future<bool> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  /// Checks if the device's Bluetooth radio is currently on. The
  /// blue_thermal_printer package has no API to programmatically trigger
  /// the system "turn on Bluetooth" prompt, so if it's off, the caller
  /// should direct the user to system settings instead (see
  /// openSystemBluetoothSettings below).
  Future<bool> isBluetoothOn() async {
    return await _bluetooth.isOn ?? false;
  }

  /// Opens the system Bluetooth settings screen — used both to let the user
  /// turn Bluetooth on manually, and to pair a new printer that isn't
  /// bonded yet. After returning to the app, they should tap "Refresh".
  Future<void> openSystemBluetoothSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  Future<void> connect(BluetoothDevice device) async {
    await _bluetooth.connect(device);
  }

  Future<void> disconnect() async {
    await _bluetooth.disconnect();
  }

  Future<void> printReceiptBytes(Uint8List bytes) async {
    final bool? connected = await _bluetooth.isConnected;
    if (connected == true) {
      await _bluetooth.writeBytes(bytes);
    } else {
      throw Exception('Printer is not connected.');
    }
  }

  /// Prints a full itemized receipt to the connected thermal printer.
  Future<void> printReceiptForSale(
    SaleTransaction sale,
    String shopName, {
    String shopPhone = '',
    String shopAddress = '',
  }) async {
    final bool? connected = await _bluetooth.isConnected;
    if (connected != true) {
      throw Exception('Printer is not connected.');
    }

    _bluetooth.printCustom(shopName.toUpperCase(), 3, 1);
    if (shopAddress.isNotEmpty) _bluetooth.printCustom(shopAddress, 1, 1);
    if (shopPhone.isNotEmpty) _bluetooth.printCustom('Tel: $shopPhone', 1, 1);
    _bluetooth.printCustom('--------------------------------', 1, 1);
    _bluetooth.printCustom('Receipt: ${sale.id}', 1, 0);
    _bluetooth.printCustom('Date: ${sale.createdAt.toString().split('.')[0]}', 1, 0);
    _bluetooth.printCustom('Payment: ${sale.paymentMethod}', 1, 0);
    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      _bluetooth.printCustom('Customer: ${sale.customerName}', 1, 0);
    }
    if (sale.mpesaCode.isNotEmpty) {
      _bluetooth.printCustom('M-Pesa Code: ${sale.mpesaCode}', 1, 0);
    }
    _bluetooth.printCustom('--------------------------------', 1, 1);

    for (var item in sale.items) {
      final line = '${item.productName} x${item.quantity}';
      final amount = (item.quantity * item.unitPrice).toStringAsFixed(0);
      _bluetooth.printLeftRight(line, amount, 1);
    }

    _bluetooth.printCustom('--------------------------------', 1, 1);
    _bluetooth.printLeftRight(
      'TOTAL',
      'KES ${sale.totalAmount.toStringAsFixed(0)}',
      2,
    );
    _bluetooth.printNewLine();
    _bluetooth.printCustom('Thank you for shopping with us!', 1, 1);
    _bluetooth.printCustom('Powered by SmartShop POS', 1, 1);
    _bluetooth.printNewLine();
    _bluetooth.paperCut();
  }
}
