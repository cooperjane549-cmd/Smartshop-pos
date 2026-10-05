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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization non-fatal warning: $e");
  }
  BillingService.instance.initialize();
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

  bool _isSubscribed = false;

  String? _autoOpenDebtSaleId;
  double? _autoOpenDebtAmount;
  List<CartItem>? _autoOpenDebtItems;

  @override
  void initState() {
    super.initState();
    _initCurrency();
    _loadFirestoreData();
  }

  Future<void> _initCurrency() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await CurrencyService.instance.initialize(user.uid);
    if (mounted) setState(() {});
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
        if (data != null && data.containsKey('expiryDate')) {
          final DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
          setState(() {
            _isSubscribed = DateTime.now().isBefore(expiry);
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
      body: IndexedStack(
        index: _currentIndex,
        children: views,
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
