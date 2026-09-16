import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../models/sale_transaction.dart';

class ThermalPrinterService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  Future<void> printReceipt(
      BluetoothDevice device, SaleTransaction sale, String shopName) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != true) {
      await bluetooth.connect(device);
    }

    bluetooth.printNewLine();
    bluetooth.printCustom(shopName, 3, 1);
    bluetooth.printCustom("SmartShop POS Receipt", 1, 1);
    bluetooth.printCustom("--------------------------------", 1, 1);

    for (var item in sale.items) {
      bluetooth.printLeftRight(
          "${item.productName} x${item.quantity}",
          "KES ${(item.unitPrice * item.quantity).toStringAsFixed(0)}",
          1);
    }

    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printLeftRight(
        "TOTAL", "KES ${sale.totalAmount.toStringAsFixed(0)}", 2);
    bluetooth.printLeftRight("Payment Mode", sale.paymentMethod, 1);
    if (sale.mpesaCode.isNotEmpty) {
      bluetooth.printLeftRight("M-Pesa Ref", sale.mpesaCode, 1);
    }
    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printCustom("Thank you for your business!", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printPaper();
  }
}
