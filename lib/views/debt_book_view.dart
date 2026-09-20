import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
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

  String _formatPhoneNumberForWhatsApp(String rawPhone) {
    String cleaned = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '254${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  void _sendWhatsAppReminder(BuildContext context, SaleTransaction sale) async {
    if (sale.customerPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number specified for this debtor.')),
      );
      return;
    }

    final formattedPhone = _formatPhoneNumberForWhatsApp(sale.customerPhone);
    final dueDateFormatted = sale.dueDate != null
        ? DateFormat('dd MMM yyyy').format(sale.dueDate!)
        : 'as agreed';

    final message =
        "Hello ${sale.customerName}, this is a friendly reminder to clear your pending balance of KES ${sale.totalAmount.toStringAsFixed(0)} at SmartShop POS. Due Date: $dueDateFormatted. Thank you!";

    final uri = Uri.parse(
        "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

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

                final bool isOverdue = sale.dueDate != null &&
                    now.isAfter(
                      DateTime(sale.dueDate!.year, sale.dueDate!.month, sale.dueDate!.day, 23, 59, 59),
                    );

                final dueDateText = sale.dueDate != null
                    ? DateFormat('dd MMM yyyy').format(sale.dueDate!)
                    : 'No Due Date Set';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isOverdue ? Colors.red : Colors.transparent,
                      width: isOverdue ? 1.5 : 0.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isOverdue ? Colors.red : Colors.indigo,
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sale.customerName.isEmpty
                                        ? 'Unnamed Customer'
                                        : sale.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Phone: ${sale.customerPhone}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'KES ${sale.totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.message, color: Colors.green),
                                      onPressed: () => _sendWhatsAppReminder(context, sale),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.blue),
                                      onPressed: () async {
                                        await LocalDbService.instance
                                            .markSalePaid(sale.id, 'MANUAL_CLEAR');
                                        onDebtCleared(sale.id, 'MANUAL_CLEAR');
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Due Date: $dueDateText',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isOverdue ? Colors.red : Colors.grey.shade800,
                              ),
                            ),
                            if (isOverdue)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LATE / DEFAULT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
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
