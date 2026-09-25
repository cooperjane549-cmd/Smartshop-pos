import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/sale_transaction.dart';

class DebtBookView extends StatefulWidget {
  final List<SaleTransaction> sales;
  final Function(String, String) onDebtCleared;

  const DebtBookView({
    Key? key,
    required this.sales,
    required this.onDebtCleared,
  }) : super(key: key);

  @override
  State<DebtBookView> createState() => _DebtBookViewState();
}

class _DebtBookViewState extends State<DebtBookView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _clearDebtInFirestore(String saleId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sales')
          .doc(saleId)
          .update({
        'isPaid': 1,
      });
    }
  }

  void _showEditCreditDialog(BuildContext context, SaleTransaction sale) {
    final TextEditingController amountController =
        TextEditingController(text: sale.totalAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit Debt (${sale.customerName})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Balance: KES ${sale.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'New Remaining Balance (KES)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () async {
                final double? newAmount = double.tryParse(amountController.text.trim());
                if (newAmount == null || newAmount < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount.')),
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  if (newAmount == 0) {
                    await _clearDebtInFirestore(sale.id);
                    widget.onDebtCleared(sale.id, 'MANUAL_CLEAR');
                  } else {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('sales')
                        .doc(sale.id)
                        .update({'totalAmount': newAmount});
                  }
                }

                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debt balance updated.')),
                  );
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debtors Ledger (Mkopo)'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search debtor by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('sales')
                  .where('paymentMethod', isEqualTo: 'CREDIT')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No outstanding customer credit.'));
                }

                final creditSales = snapshot.data!.docs
                    .map((doc) => SaleTransaction.fromMap(doc.data() as Map<String, dynamic>))
                    .where((sale) => !sale.isPaid)
                    .where((sale) {
                      if (_searchQuery.isEmpty) return true;
                      final nameMatch = sale.customerName.toLowerCase().contains(_searchQuery);
                      final phoneMatch = sale.customerPhone.toLowerCase().contains(_searchQuery);
                      return nameMatch || phoneMatch;
                    })
                    .toList();

                if (creditSales.isEmpty) {
                  return const Center(child: Text('No debtors match your search.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                          icon: const Icon(Icons.edit, color: Colors.orange),
                                          onPressed: () => _showEditCreditDialog(context, sale),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.message, color: Colors.green),
                                          onPressed: () => _sendWhatsAppReminder(context, sale),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.blue),
                                          onPressed: () async {
                                            await _clearDebtInFirestore(sale.id);
                                            widget.onDebtCleared(sale.id, 'MANUAL_CLEAR');
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
