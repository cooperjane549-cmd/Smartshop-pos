import 'package:flutter/material.dart';
import '../models/sale_transaction.dart';

class DashboardView extends StatelessWidget {
  final List<SaleTransaction> sales;

  const DashboardView({Key? key, required this.sales}) : super(key: key);

  double get _cashRevenue {
    return sales
        .where((s) => s.paymentMode == 'CASH' && s.isPaid)
        .fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  double get _mpesaRevenue {
    return sales
        .where((s) => s.paymentMode == 'M-PESA' && s.isPaid)
        .fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  double get _uncollectedCredit {
    return sales
        .where((s) => !s.isPaid)
        .fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartShop Dashboard'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Revenue Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RevenueCard(
                    title: 'Cash',
                    amount: _cashRevenue,
                    color: Colors.green.shade50,
                    textColor: Colors.green.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RevenueCard(
                    title: 'M-Pesa',
                    amount: _mpesaRevenue,
                    color: Colors.blue.shade50,
                    textColor: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RevenueCard(
              title: 'Uncollected Credit',
              amount: _uncollectedCredit,
              color: Colors.red.shade50,
              textColor: Colors.red.shade800,
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Sales Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            sales.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No recorded sales yet.'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales.reversed.toList()[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    sale.id,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'KES ${sale.totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Mode: ${sale.paymentMode} | Status: ${sale.isPaid ? "PAID" : "UNPAID"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (sale.mpesaCode != null &&
                                  sale.mpesaCode!.isNotEmpty)
                                Text(
                                  'M-Pesa Code: ${sale.mpesaCode}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              const Divider(height: 12),
                              const Text(
                                'Items:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              ...sale.items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '• ${item.productName} x${item.quantity}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      Text(
                                        'KES ${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final Color textColor;

  const _RevenueCard({
    Key? key,
    required this.title,
    required this.amount,
    required this.color,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'KES ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
