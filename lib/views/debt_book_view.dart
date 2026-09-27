import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/sale_transaction.dart';
import '../services/local_db_service.dart';

class DebtBookView extends StatefulWidget {
  final List<SaleTransaction> sales;
  final Function(String, String) onDebtCleared;
  // When set, DebtBookView auto-opens the Add Debt dialog for this sale ID,
  // pre-filled with the given amount/items — used when PosView hands off a
  // credit sale that matches an existing debtor.
  final String? autoOpenSaleId;
  final double? autoAddAmount;
  final List<CartItem>? autoAddItems;
  final VoidCallback? onAutoAddHandled;

  const DebtBookView({
    Key? key,
    required this.sales,
    required this.onDebtCleared,
    this.autoOpenSaleId,
    this.autoAddAmount,
    this.autoAddItems,
    this.onAutoAddHandled,
  }) : super(key: key);

  @override
  State<DebtBookView> createState() => _DebtBookViewState();
}

class _DebtBookViewState extends State<DebtBookView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _autoOpenTriggered = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DebtBookView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoOpenSaleId != null &&
        widget.autoOpenSaleId != oldWidget.autoOpenSaleId) {
      _autoOpenTriggered = false;
    }
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
    
    // Local SQLite Update
    final localSaleMap = {
      'id': saleId,
      'isPaid': 1,
      'totalAmount': 0.0,
    };
    await LocalDbService.instance.insertSale(localSaleMap);

    // Firestore Update
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sales')
          .doc(saleId)
          .update({
        'isPaid': 1,
        'totalAmount': 0.0,
      });
    }
  }

  void _showRepaymentDialog(
    BuildContext context,
    SaleTransaction sale, {
    String initialActionMode = 'PAY',
    double? initialAmount,
    List<CartItem>? initialItems,
  }) {
    final TextEditingController amountController = TextEditingController(
      text: initialAmount != null ? initialAmount.toStringAsFixed(0) : '',
    );
    String paymentMode = 'CASH';
    String actionMode = initialActionMode;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isAddMode = actionMode == 'ADD';

            return AlertDialog(
              title: Text(
                isAddMode
                    ? 'Add Debt (${sale.customerName})'
                    : 'Record Payment (${sale.customerName})',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle between recording a payment and adding new debt
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Record Payment')),
                          selected: actionMode == 'PAY',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (val) => setDialogState(() => actionMode = 'PAY'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Add Debt')),
                          selected: actionMode == 'ADD',
                          selectedColor: Colors.orange.shade100,
                          onSelected: (val) => setDialogState(() => actionMode = 'ADD'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Current Balance: KES ${sale.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  if (isAddMode && initialItems != null && initialItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Items from this purchase:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          ...initialItems.map(
                            (item) => Text(
                              '• ${item.productName} x${item.quantity} = KES ${(item.quantity * item.unitPrice).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isAddMode ? 'Amount to Add (KES)' : 'Amount Paid (KES)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isAddMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ChoiceChip(
                          label: const Text('CASH'),
                          selected: paymentMode == 'CASH',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (val) => setDialogState(() => paymentMode = 'CASH'),
                        ),
                        ChoiceChip(
                          label: const Text('M-PESA'),
                          selected: paymentMode == 'MPESA',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (val) => setDialogState(() => paymentMode = 'MPESA'),
                        ),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAddMode ? Colors.orange.shade800 : Colors.indigo,
                  ),
                  onPressed: () async {
                    final double enteredAmount = double.tryParse(amountController.text.trim()) ?? 0;
                    if (enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isAddMode
                                ? 'Please enter a valid amount to add.'
                                : 'Please enter a valid amount paid.',
                          ),
                        ),
                      );
                      return;
                    }

                    final user = FirebaseAuth.instance.currentUser;
                    final now = DateTime.now();

                    if (isAddMode) {
                      // ----- ADD DEBT FLOW -----
                      final double newBalance = sale.totalAmount + enteredAmount;

                      // Use the itemized cart from the POS hand-off if present,
                      // otherwise fall back to a generic labeled line item.
                      final List<CartItem> additionItems =
                          (initialItems != null && initialItems.isNotEmpty)
                              ? initialItems
                              : [
                                  CartItem(
                                    productId: 'DEBT_ADDITION',
                                    productName: 'Debt Added (${sale.customerName})',
                                    quantity: 1,
                                    unitPrice: enteredAmount,
                                  )
                                ];

                      // 1. Record this debt addition as its own transaction for history/audit
                      final String additionSaleId = 'DEBTADD_${now.millisecondsSinceEpoch}';
                      final additionSale = SaleTransaction(
                        id: additionSaleId,
                        totalAmount: enteredAmount,
                        paymentMethod: 'CREDIT',
                        isPaid: false,
                        items: additionItems,
                        customerName: sale.customerName,
                        customerPhone: sale.customerPhone,
                        dueDate: sale.dueDate,
                        createdAt: now,
                      );

                      Map<String, dynamic> additionMap = additionSale.toMap();
                      additionMap['items'] =
                          jsonEncode(additionSale.items.map((e) => e.toMap()).toList());

                      await LocalDbService.instance.insertSale(additionMap);
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('sales')
                            .doc(additionSaleId)
                            .set(additionMap);
                      }

                      // 2. Update the original credit sale's balance upward
                      final updatedSale = SaleTransaction(
                        id: sale.id,
                        totalAmount: newBalance,
                        paymentMethod: sale.paymentMethod,
                        isPaid: false,
                        items: sale.items,
                        customerName: sale.customerName,
                        customerPhone: sale.customerPhone,
                        dueDate: sale.dueDate,
                        createdAt: sale.createdAt,
                      );

                      Map<String, dynamic> updatedCreditSaleMap = updatedSale.toMap();
                      updatedCreditSaleMap['items'] =
                          jsonEncode(updatedSale.items.map((e) => e.toMap()).toList());

                      await LocalDbService.instance.insertSale(updatedCreditSaleMap);
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('sales')
                            .doc(sale.id)
                            .update({
                          'totalAmount': newBalance,
                          'isPaid': 0,
                        });
                      }

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added KES ${enteredAmount.toStringAsFixed(0)} debt. New balance: KES ${newBalance.toStringAsFixed(0)}',
                            ),
                          ),
                        );
                      }
                    } else {
                      // ----- RECORD PAYMENT FLOW (unchanged existing behavior) -----
                      final double paidAmount = enteredAmount;

                      // 1. Record payment cashflow transaction
                      final String repaymentSaleId = 'REP_${now.millisecondsSinceEpoch}';
                      final repaymentSale = SaleTransaction(
                        id: repaymentSaleId,
                        totalAmount: paidAmount,
                        paymentMethod: paymentMode,
                        isPaid: true,
                        items: [
                          CartItem(
                            productId: 'DEBT_PAYMENT',
                            productName: 'Debt Repayment (${sale.customerName})',
                            quantity: 1,
                            unitPrice: paidAmount,
                          )
                        ],
                        customerName: sale.customerName,
                        customerPhone: sale.customerPhone,
                        createdAt: now,
                      );

                      Map<String, dynamic> repaymentMap = repaymentSale.toMap();
                      repaymentMap['items'] = jsonEncode(repaymentSale.items.map((e) => e.toMap()).toList());

                      // Save payment locally & cloud
                      await LocalDbService.instance.insertSale(repaymentMap);
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('sales')
                            .doc(repaymentSaleId)
                            .set(repaymentMap);
                      }

                      // 2. Adjust original credit balance
                      final double remainingBalance = sale.totalAmount - paidAmount;
                      final bool isFullyPaid = remainingBalance <= 0;
                      final double newBalance = remainingBalance < 0 ? 0 : remainingBalance;

                      // Create updated SaleTransaction object without mutating final fields
                      final updatedSale = SaleTransaction(
                        id: sale.id,
                        totalAmount: newBalance,
                        paymentMethod: sale.paymentMethod,
                        isPaid: isFullyPaid,
                        items: sale.items,
                        customerName: sale.customerName,
                        customerPhone: sale.customerPhone,
                        dueDate: sale.dueDate,
                        createdAt: sale.createdAt,
                      );

                      Map<String, dynamic> updatedCreditSaleMap = updatedSale.toMap();
                      updatedCreditSaleMap['items'] = jsonEncode(updatedSale.items.map((e) => e.toMap()).toList());

                      await LocalDbService.instance.insertSale(updatedCreditSaleMap);
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('sales')
                            .doc(sale.id)
                            .update({
                          'totalAmount': newBalance,
                          'isPaid': isFullyPaid ? 1 : 0,
                        });
                      }

                      if (isFullyPaid) {
                        widget.onDebtCleared(sale.id, paymentMode);
                      }

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Recorded payment of KES ${paidAmount.toStringAsFixed(0)} via $paymentMode',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    isAddMode ? 'Add Debt' : 'Save Payment',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
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
                    .where((sale) => !sale.isPaid && sale.totalAmount > 0)
                    .where((sale) {
                      if (_searchQuery.isEmpty) return true;
                      final nameMatch = sale.customerName.toLowerCase().contains(_searchQuery);
                      final phoneMatch = sale.customerPhone.toLowerCase().contains(_searchQuery);
                      return nameMatch || phoneMatch;
                    })
                    .toList();

                // If PosView handed off a "merge this sale into existing debtor"
                // request, auto-open the Add Debt dialog for it, pre-filled.
                if (widget.autoOpenSaleId != null && !_autoOpenTriggered) {
                  final matchIndex =
                      creditSales.indexWhere((s) => s.id == widget.autoOpenSaleId);
                  if (matchIndex >= 0) {
                    _autoOpenTriggered = true;
                    final matchedSale = creditSales[matchIndex];
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _showRepaymentDialog(
                        context,
                        matchedSale,
                        initialActionMode: 'ADD',
                        initialAmount: widget.autoAddAmount,
                        initialItems: widget.autoAddItems,
                      );
                      widget.onAutoAddHandled?.call();
                    });
                  }
                }

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
                                          icon: const Icon(Icons.payments, color: Colors.indigo),
                                          tooltip: 'Record Payment / Add Debt',
                                          onPressed: () => _showRepaymentDialog(context, sale),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.message, color: Colors.green),
                                          tooltip: 'WhatsApp Reminder',
                                          onPressed: () => _sendWhatsAppReminder(context, sale),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.blue),
                                          tooltip: 'Clear Entire Debt',
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
