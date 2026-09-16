import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class ThermalPrinterService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  Future<bool> isConnected() async {
    return (await _bluetooth.isConnected) ?? false;
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
      // Replaced undefined printPaper with writeBytes for raw ESC/POS byte data
      await _bluetooth.writeBytes(bytes);
    } else {
      throw Exception('Printer is not connected.');
    }
  }

  Future<void> printTextSample(String title, String message) async {
    final bool? connected = await _bluetooth.isConnected;
    if (connected == true) {
      _bluetooth.printCustom(title, 3, 1);
      _bluetooth.printNewLine();
      _bluetooth.printCustom(message, 1, 0);
      _bluetooth.printNewLine();
      _bluetooth.paperCut();
    }
  }
}
