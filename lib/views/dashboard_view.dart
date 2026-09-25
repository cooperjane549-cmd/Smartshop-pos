import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale_transaction.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import 'upgrade_dialog.dart';

class DashboardView extends StatefulWidget {
  final List<SaleTransaction> sales;

  const DashboardView({Key? key, required this.sales}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter sales to show only records from the last 60 days (Option C Active View)
  List<SaleTransaction> get _activeSales {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 60));
    return widget.sales
        .where((s) => s.createdAt.isAfter(cutoffDate))
        .toList();
  }

  double get cashCollected => _activeSales
      .where((s) => s.paymentMethod == 'CASH')
      .fold(0, (sum, s) => sum + s.totalAmount);

  double get mpesaCollected => _activeSales
      .where((s) =>
          s.paymentMethod == 'MPESA' ||
          (s.paymentMethod == 'CREDIT' && s.isPaid))
      .fold(0, (sum, s) => sum + s.totalAmount);

  double get openCredit => _activeSales
      .where((s) => s.paymentMethod == 'CREDIT' && !s.isPaid)
      .fold(0, (sum, s) => sum + s.totalAmount);

  // Initialize automatic 10-day free trial for first-time users
  Future<void> _ensureTrialInitialized(String uid) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('status');

    final doc = await docRef.get();
    if (!doc.exists) {
      final trialExpiry = DateTime.now().add(const Duration(days: 10));
      await docRef.set({
        'isSubscribed': false,
        'expiryDate': Timestamp.fromDate(trialExpiry),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Delete a single sale transaction completely
  Future<void> _deleteSaleTransaction(SaleTransaction sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Text('Are you sure you want to delete Sale ${sale.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      
      // Clear locally
      await LocalDbService.instance.deleteSale(sale.id);
      
      // Remove from Firestore
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sales')
            .doc(sale.id)
            .delete();
      }

      setState(() {
        widget.sales.removeWhere((s) => s.id == sale.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale ${sale.id} deleted.')),
        );
      }
    }
  }

  // Option C: Manual Purge Action Dialog
  void _showClearHistoryDialog() {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 60));
    final olderSales = widget.sales
        .where((s) => s.createdAt.isBefore(cutoffDate))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Sales History'),
        content: Text(
          olderSales.isEmpty
              ? 'No sales records older than 60 days were found in memory.'
              : 'Found ${olderSales.length} sale(s) older than 60 days. Would you like to clear them to keep your local database light?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (olderSales.isNotEmpty)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                for (var sale in olderSales) {
                  // Clear locally
                  await LocalDbService.instance.deleteSale(sale.id);
                  // Remove from Firestore
                  if (user != null) {
                    await _firestore
                        .collection('users')
                        .doc(user.uid)
                        .collection('sales')
                        .doc(sale.id)
                        .delete();
                  }
                  widget.sales.removeWhere((s) => s.id == sale.id);
                }
                setState(() {});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sales older than 60 days successfully cleared.'),
                  ),
                );
              },
              child: const Text('Clear Old Data',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _authService.currentUser;

    if (user != null) {
      _ensureTrialInitialized(user.uid);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? _firestore
              .collection('users')
              .doc(user.uid)
              .collection('subscription')
              .doc('status')
              .snapshots()
          : null,
      builder: (context, snapshot) {
        bool isProUser = false;
        DateTime? expiryDate;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            isProUser = data['isSubscribed'] ?? false;
            if (data['expiryDate'] != null) {
              expiryDate = (data['expiryDate'] as Timestamp).toDate();
            }
          }
        }

        final now = DateTime.now();
        
        // Lock screen activates if NOT a paying pro user AND expiry date has passed
        final bool isExpired = !isProUser && (expiryDate != null && now.isAfter(expiryDate));

        int daysRemaining = 0;
        if (expiryDate != null) {
          daysRemaining = expiryDate.difference(now).inDays;
          if (daysRemaining < 0) daysRemaining = 0;
        }

        final activeList = _activeSales;

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
              // Main Dashboard Content
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
                              backgroundImage: (user?.photoURL != null &&
                                      user!.photoURL!.isNotEmpty)
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                              child: (user?.photoURL == null ||
                                      user!.photoURL!.isEmpty)
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

                    // Subscription Banner Card
                    Card(
                      elevation: 2,
                      color: isProUser
                          ? Colors.indigo.shade900
                          : Colors.amber.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isProUser
                              ? Colors.indigo
                              : Colors.amber.shade400,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              isProUser
                                  ? Icons.verified_rounded
                                  : Icons.timer_outlined,
                              size: 36,
                              color: isProUser
                                  ? Colors.amber
                                  : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isProUser
                                        ? 'PRO PLAN ACTIVE'
                                        : '10-DAY FREE TRIAL',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isProUser
                                          ? Colors.white
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    expiryDate == null
                                        ? 'Setting up trial...'
                                        : isProUser
                                            ? 'Renews in $daysRemaining days'
                                            : '$daysRemaining days left on trial',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isProUser
                                          ? Colors.white70
                                          : Colors.amber.shade900,
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
                              onPressed: () => UpgradeDialog.show(context),
                              child: Text(isProUser ? 'Renew' : 'Upgrade'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Revenue Overview
                    const Text(
                      'Daily Revenue Overview',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                    // Recent Sales Header & Option C Purge Trigger
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Sales (60 Days)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _showClearHistoryDialog,
                          icon: const Icon(Icons.cleaning_services, size: 16),
                          label: const Text('Manage History',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    activeList.isEmpty
                        ? const Text('No transactions in the last 60 days.')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: activeList.length,
                            itemBuilder: (context, idx) {
                              final sale =
                                  activeList[activeList.length - 1 - idx];
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          Row(
                                            children: [
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
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                tooltip: 'Delete Sale',
                                                onPressed: () =>
                                                    _deleteSaleTransaction(sale),
                                              ),
                                            ],
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
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                              Text(
                                                'KES ${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    fontSize: 13),
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

              // Full Screen Overlay after 10-Day Free Trial Expires
              if (isExpired)
                Container(
                  color: Colors.indigo.shade900,
                  width: double.infinity,
                  height: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        size: 90,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '10-Day Free Trial Expired',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Your free trial period has ended. To continue using SmartShop POS, please subscribe to one of our plans using Buy Goods Till 3043489.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => UpgradeDialog.show(context),
                        child: const Text(
                          'Upgrade Now (From KES 100)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
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
