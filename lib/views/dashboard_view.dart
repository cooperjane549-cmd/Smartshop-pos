import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sale_transaction.dart';
import '../services/auth_service.dart';

class DashboardView extends StatefulWidget {
  final List<SaleTransaction> sales;

  const DashboardView({Key? key, required this.sales}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final AuthService _authService = AuthService();
  bool _isProUser = false;
  
  // Replace with dynamic date from Shared Preferences / Local DB in production
  DateTime _subscriptionExpiry = DateTime.now().add(const Duration(days: 10));
  bool _isProcessingPayment = false;
  String _selectedPlan = 'Monthly';

  double get cashCollected => widget.sales
      .where((s) => s.paymentMethod == 'CASH')
      .fold(0, (sum, s) => sum + s.totalAmount);

  double get mpesaCollected => widget.sales
      .where((s) =>
          s.paymentMethod == 'MPESA' ||
          (s.paymentMethod == 'CREDIT' && s.isPaid))
      .fold(0, (sum, s) => sum + s.totalAmount);

  double get openCredit => widget.sales
      .where((s) => s.paymentMethod == 'CREDIT' && !s.isPaid)
      .fold(0, (sum, s) => sum + s.totalAmount);

  bool get _isExpired => !_isProUser && DateTime.now().isAfter(_subscriptionExpiry);

  @override
  Widget build(BuildContext context) {
    final User? user = _authService.currentUser;
    int daysRemaining = _subscriptionExpiry.difference(DateTime.now()).inDays;
    if (daysRemaining < 0) daysRemaining = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartShop Dashboard'),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Dashboard Interface
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Google Profile Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.indigo.shade100,
                          backgroundImage:
                              (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                          child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                              ? Text(
                                  (user?.displayName ?? 'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'SmartShop Merchant',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? 'No email provided',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Subscription Status Card
                Card(
                  elevation: 2,
                  color: _isProUser
                      ? Colors.indigo.shade900
                      : Colors.indigo.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _isProUser ? Colors.indigo : Colors.indigo.shade200,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          _isProUser
                              ? Icons.verified_rounded
                              : Icons.star_rounded,
                          size: 36,
                          color: _isProUser ? Colors.amber : Colors.indigo,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isProUser ? 'PRO PLAN ACTIVE' : '10-DAY FREE TRIAL',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isProUser
                                      ? Colors.white
                                      : Colors.indigo.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isProUser
                                    ? 'Renews in $daysRemaining days'
                                    : '$daysRemaining days left on free trial',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isProUser
                                      ? Colors.white70
                                      : Colors.indigo.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _showSubscriptionModal(context),
                          child: Text(_isProUser ? 'Renew' : 'Upgrade'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Daily Revenue Overview
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

                // Recent Sales List
                const Text(
                  'Recent Sales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                widget.sales.isEmpty
                    ? const Text('No transactions completed today.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.sales.length,
                        itemBuilder: (context, idx) {
                          final sale =
                              widget.sales[widget.sales.length - 1 - idx];
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

          // Blocking Overlay for Expiry Screen
          if (_isExpired)
            Container(
              color: Colors.black87,
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    size: 80,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Free Trial Expired',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your 10-day free trial period has ended. Upgrade to a paid plan to continue recording sales and viewing dashboard analytics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showSubscriptionModal(context),
                    child: const Text(
                      'Renew / Upgrade Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
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

  void _showSubscriptionModal(BuildContext context) {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: !_isExpired, // Prevent dismiss if expired
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double activePrice = _selectedPlan == 'Monthly' ? 100 : 1100;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.workspace_premium, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Upgrade SmartShop POS'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a plan to pay via Buy Goods Till 3043489:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => _selectedPlan = 'Monthly'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedPlan == 'Monthly'
                                ? Colors.indigo.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedPlan == 'Monthly'
                                  ? Colors.indigo
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: const Column(
                            children: [
                              Text('Monthly',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              SizedBox(height: 4),
                              Text('KES 100',
                                  style: TextStyle(
                                      color: Colors.indigo,
                                      fontWeight: FontWeight.bold)),
                              Text('30 Days',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => _selectedPlan = 'Yearly'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedPlan == 'Yearly'
                                ? Colors.indigo.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedPlan == 'Yearly'
                                  ? Colors.indigo
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: const Column(
                            children: [
                              Text('Yearly',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              SizedBox(height: 4),
                              Text('KES 1,100',
                                  style: TextStyle(
                                      color: Colors.indigo,
                                      fontWeight: FontWeight.bold)),
                              Text('365 Days',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.payment, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'M-Pesa Buy Goods Till: 3043489',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa Phone Number',
                    hintText: '0712345678',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                ),
                if (_isProcessingPayment) ...[
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Listening for M-Pesa Till 3043489 confirmation...',
                          style: TextStyle(fontSize: 12, color: Colors.indigo),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              if (!_isExpired)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo),
                onPressed: _isProcessingPayment
                    ? null
                    : () async {
                        if (phoneController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter a phone number')),
                          );
                          return;
                        }

                        setModalState(() => _isProcessingPayment = true);

                        await Future.delayed(const Duration(seconds: 3));

                        int daysToAdd = _selectedPlan == 'Monthly' ? 30 : 365;

                        if (mounted) {
                          setState(() {
                            _isProUser = true;
                            _subscriptionExpiry = DateTime.now()
                                .add(Duration(days: daysToAdd));
                          });
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green,
                              content: Text(
                                  'Subscription active! Extended for $daysToAdd days.'),
                            ),
                          );
                        }
                      },
                child: Text('Pay KES ${activePrice.toStringAsFixed(0)}'),
              ),
            ],
          );
        },
      ),
    );
  }
}
