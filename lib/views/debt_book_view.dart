import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale_transaction.dart';
import '../services/local_db_service.dart';

class DebtBookView extends StatelessWidget {
  final List<SaleTransaction> sales;
  final Function(String, String) onDebtCleared;

  const DebtBookView({
    Key? key,
    required this.sales,
    required this.onDebtCleared,
  }) : super(key: key);

  List<SaleTransaction> get creditSales =>
      sales.where((s) => s.paymentMethod == 'CREDIT' && !s.isPaid).toList();

  void _sendWhatsAppReminder(SaleTransaction sale) async {
    final message =
        "Hello ${sale.customerName}, gentle reminder to clear your pending balance of KES ${sale.totalAmount.toStringAsFixed(0)} at SmartShop POS. Thank you!";
    final uri = Uri.parse(
        "https://wa.me/${sale.customerPhone}?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debtors Ledger (Mkopo)'),
        backgroundColor: Colors.indigo,
      ),
      body: creditSales.isEmpty
          ? const Center(child: Text('No outstanding customer credit.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: creditSales.length,
              itemBuilder: (context, idx) {
                final sale = creditSales[idx];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(sale.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Phone: ${sale.customerPhone}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KES ${sale.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.green),
                          onPressed: () => _sendWhatsAppReminder(sale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.blue),
                          onPressed: () async {
                            await LocalDbService.instance
                                .markSalePaid(sale.id, 'MANUAL_CLEAR');
                            onDebtCleared(sale.id, 'MANUAL_CLEAR');
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
