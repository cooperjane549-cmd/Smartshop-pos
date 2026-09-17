
import 'package:flutter/material.dart';
import '../models/sale_transaction.dart';

class DashboardView extends StatelessWidget {
  final List<SaleTransaction> sales;

  const DashboardView({Key? key, required this.sales}) : super(key: key);

  double get cashCollected => sales
      .where((s) => s.paymentMethod == 'CASH')
      .fold(0, (sum, s) => sum + s.totalAmount);

  double get mpesaCollected => sales
      .where((s) =>
          s.paymentMethod == 'MPESA' ||
          (s.paymentMethod == 'CREDIT' && s.isPaid))
      .fold(0, (sum, s) => sum + s.totalAmount);

  double get openCredit => sales
      .where((s) => s.paymentMethod == 'CREDIT' && !s.isPaid)
      .fold(0, (sum, s) => sum + s.totalAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartShop Dashboard'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                  child: _buildTile(
                    'Cash',
                    'KES ${cashCollected.toStringAsFixed(0)}',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTile(
                    'M-Pesa',
                    'KES ${mpesaCollected.toStringAsFixed(0)}',
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTile(
              'Uncollected Credit',
              'KES ${openCredit.toStringAsFixed(0)}',
              Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Recent Sales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            sales.isEmpty
                ? const Text('No transactions completed today.')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sales.length,
                    itemBuilder: (context, idx) {
                      final sale = sales[sales.length - 1 - idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sale ${sale.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'KES ${sale.totalAmount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: sale.isPaid
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mode: ${sale.paymentMethod} | Status: ${sale.isPaid ? "PAID" : "UNPAID"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (sale.customerName != null &&
                                  sale.customerName!.isNotEmpty)
                                Text(
                                  'Customer: ${sale.customerName} (${sale.customerPhone ?? "No Phone"})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              const Divider(height: 12),
                              const Text(
                                'Purchased Items:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                  )
          ],
        ),
      ),
    );
  }

  Widget _buildTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
