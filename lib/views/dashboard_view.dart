import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale_transaction.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../services/referral_service.dart';
import '../services/currency_service.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/currency_dialog.dart';
import 'upgrade_dialog.dart';
import 'terms_view.dart';

const String kContactWhatsapp = '0789574046';
const String kContactPhone = '+254789574046';
const String kContactEmail = 'microgiger@gmail.com';

class DashboardView extends StatefulWidget {
  final List<SaleTransaction> sales;

  const DashboardView({Key? key, required this.sales}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _currency => CurrencyService.symbol;

  List<SaleTransaction> get _activeSales {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 60));
    return widget.sales
        .where((s) => s.createdAt.isAfter(cutoffDate))
        .toList();
  }

  double get cashCollected => _activeSales
      .where((s) => s.paymentMethod == 'CASH')
      .fold(0, (sum, s) => sum + s.totalAmount);

  double get otherCollected => _activeSales
      .where((s) =>
          s.paymentMethod == 'OTHER' ||
          (s.paymentMethod == 'CREDIT' && s.isPaid))
      .fold(0, (sum, s) => sum + s.totalAmount);

  double get openCredit => _activeSales
      .where((s) => s.paymentMethod == 'CREDIT' && !s.isPaid)
      .fold(0, (sum, s) => sum + s.totalAmount);

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

  Future<void> _deleteSaleTransaction(SaleTransaction sale) async {
    final verified = await PinDialog.verify(
      context,
      reason: 'Enter PIN to delete this sale.',
    );
    if (!verified) return;

    if (!mounted) return;

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

      await LocalDbService.instance.deleteSale(sale.id);

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
                  await LocalDbService.instance.deleteSale(sale.id);
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

  Future<void> _shareReferralCode(String code) async {
    final message =
        "Hey! I'm using SmartShop POS to manage my shop's sales, stock, and credit (mkopo) tracking. "
        "Try it out and enter my referral code when you sign up: $code";
    final uri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildReferralCard(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        String code = '...';
        int qualifiedCount = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          code = data?['referralCode'] ?? '...';
          qualifiedCount = (data?['referralQualifiedCount'] ?? 0) as int;
        }

        final remaining = ReferralService.referralsNeededForReward -
            (qualifiedCount % ReferralService.referralsNeededForReward);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.indigo, size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Refer & Earn',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Refer 5 shop owners who upgrade to Pro and get 1 free month.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.indigo,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _shareReferralCode(code),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$qualifiedCount qualified referral(s) so far — $remaining more for your next free month.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactAndTermsCard(String uid) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Us',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat, color: Colors.green),
              title: Text('WhatsApp: $kContactWhatsapp'),
              onTap: () async {
                final phone = kContactWhatsapp.replaceAll(RegExp(r'\D'), '');
                final formatted =
                    phone.startsWith('0') ? '254${phone.substring(1)}' : phone;
                final uri = Uri.parse('https://wa.me/$formatted');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.call, color: Colors.indigo),
              title: Text('Call: $kContactPhone'),
              onTap: () async {
                final uri = Uri.parse('tel:$kContactPhone');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email, color: Colors.orange),
              title: Text('Email: $kContactEmail'),
              onTap: () async {
                final uri = Uri.parse('mailto:$kContactEmail');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_money, color: Colors.teal),
              title: Text('Currency: ${CurrencyService.code}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final changed = await CurrencyDialog.show(context, uid);
                if (changed && mounted) setState(() {});
              },
            ),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined, color: Colors.grey),
              title: const Text('Terms & Conditions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TermsView()),
                );
              },
            ),
          ],
        ),
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 12),

                if (user != null) _buildReferralCard(user.uid),
                const SizedBox(height: 12),

                if (user != null) _buildContactAndTermsCard(user.uid),
                const SizedBox(height: 20),

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
                        '$_currency ${cashCollected.toStringAsFixed(0)}',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTile(
                        'Other',
                        '$_currency ${otherCollected.toStringAsFixed(0)}',
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTile(
                  'Uncollected Credit',
                  '$_currency ${openCredit.toStringAsFixed(0)}',
                  Colors.red,
                ),
                const SizedBox(height: 20),

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
                                            '$_currency ${sale.totalAmount.toStringAsFixed(0)}',
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
                                            '$_currency ${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
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
