import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/product.dart';
import 'models/sale_transaction.dart';
import 'services/referral_service.dart';
import 'services/currency_service.dart';
import 'services/billing_service.dart';
import 'views/dashboard_view.dart';
import 'views/pos_view.dart';
import 'views/inventory_view.dart';
import 'views/debt_book_view.dart';
import 'views/auth_gate.dart';
import 'views/upgrade_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization non-fatal warning: $e");
  }

  try {
    BillingService.instance.initialize();
  } catch (e) {
    debugPrint("Billing initialization error (non-fatal): $e");
  }

  runApp(const SmartShopApp());
}

class SmartShopApp extends StatelessWidget {
  const SmartShopApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartShop POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        useMaterial3: false,
      ),
      home: const AuthGate(),
    );
  }
}

class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({Key? key}) : super(key: key);

  @override
  _MainNavigationHubState createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0;
  final List<Product> _products = [];
  final List<SaleTransaction> _sales = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Subscription state is now tracked here, at the hub level, so the
  // trial-expired lock can block EVERY screen (Sell, Stock, Debtors, not
  // just Dashboard) rather than only the one screen that used to check it.
  bool _isProUser = false;
  DateTime? _expiryDate;

  String? _autoOpenDebtSaleId;
  double? _autoOpenDebtAmount;
  List<CartItem>? _autoOpenDebtItems;

  bool get _isExpired =>
      !_isProUser && _expiryDate != null && DateTime.now().isAfter(_expiryDate!);

  @override
  void initState() {
    super.initState();
    _initCurrency();
    _loadFirestoreData();
  }

  Future<void> _initCurrency() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await CurrencyService.instance.initialize(user.uid);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Currency initialization error (non-fatal): $e");
    }
  }

  void _loadFirestoreData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sales')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final loadedSales = snapshot.docs
            .map((doc) => SaleTransaction.fromMap(doc.data()))
            .toList();
        setState(() {
          _sales.clear();
          _sales.addAll(loadedSales);
        });
      });

      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final loadedProducts = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return Product.fromMap(data);
        }).toList();
        setState(() {
          _products.clear();
          _products.addAll(loadedProducts);
        });
      });

      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('status')
          .snapshots()
          .listen((doc) {
        if (!mounted || !doc.exists) return;
        final data = doc.data();
        if (data != null) {
          setState(() {
            _isProUser = data['isSubscribed'] ?? false;
            if (data['expiryDate'] != null) {
              _expiryDate = (data['expiryDate'] as Timestamp).toDate();
            }
          });

          final bool isSubscribedFlag = data['isSubscribed'] ?? false;
          if (isSubscribedFlag) {
            ReferralService.instance.onUserUpgraded(user.uid);
          }
        }
      });
    } catch (e) {
      debugPrint("Firestore data synchronization error: $e");
    }
  }

  void _switchToDebtorsTab() {
    if (mounted) {
      setState(() {
        _currentIndex = 3;
      });
    }
  }

  void _handleSaleCompleted(SaleTransaction sale) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sales')
            .doc(sale.id)
            .set(sale.toMap());
      } catch (e) {
        debugPrint("Error saving completed sale to Firestore: $e");
      }
    }
  }

  void _handleExistingDebtFound(
    String saleId,
    double amount,
    List<CartItem> items,
  ) {
    if (!mounted) return;
    setState(() {
      _autoOpenDebtSaleId = saleId;
      _autoOpenDebtAmount = amount;
      _autoOpenDebtItems = items;
      _currentIndex = 3;
    });
  }

  void _clearAutoOpenDebt() {
    if (!mounted) return;
    setState(() {
      _autoOpenDebtSaleId = null;
      _autoOpenDebtAmount = null;
      _autoOpenDebtItems = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      DashboardView(sales: _sales),
      PosView(
        products: _products,
        sales: _sales,
        onSaleCompleted: (sale) {
          _handleSaleCompleted(sale);
        },
        onCreditSelected: _switchToDebtorsTab,
        onExistingDebtFound: _handleExistingDebtFound,
      ),
      InventoryView(
        products: _products,
        onProductAdded: (p) {
          if (mounted) {
            setState(() => _products.add(p));
          }
        },
        onProductUpdated: (p) {
          if (mounted) {
            setState(() {
              int idx = _products.indexWhere((item) => item.id == p.id);
              if (idx >= 0) {
                _products[idx] = p;
              }
            });
          }
        },
        onProductDeleted: (id) {
          if (mounted) {
            setState(() {
              _products.removeWhere((item) => item.id == id);
            });
          }
        },
      ),
      DebtBookView(
        sales: _sales,
        onDebtCleared: (saleId, mpesaCode) async {
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('sales')
                .doc(saleId)
                .update({
              'isPaid': true,
              'mpesaCode': mpesaCode,
            });
          }
        },
        autoOpenSaleId: _autoOpenDebtSaleId,
        autoAddAmount: _autoOpenDebtAmount,
        autoAddItems: _autoOpenDebtItems,
        onAutoAddHandled: _clearAutoOpenDebt,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: views,
          ),

          // Full-screen lock — rendered on top of whichever tab is open,
          // so it blocks Sell, Stock, and Debtors exactly the same way it
          // blocks Dashboard, instead of only covering one screen.
          if (_isExpired)
            Positioned.fill(
              child: Container(
                color: Colors.indigo.shade900,
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
                      'Your free trial period has ended. Subscribe to a plan to continue using SmartShop POS.',
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
                        'Upgrade Now',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (idx) {
          if (mounted) {
            setState(() => _currentIndex = idx);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Summary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Sell',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Debtors',
          ),
        ],
      ),
    );
  }
}
