import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/product.dart';
import 'models/sale_transaction.dart';
import 'services/local_db_service.dart';
import 'services/sms_parser_service.dart';
import 'views/dashboard_view.dart';
import 'views/pos_view.dart';
import 'views/inventory_view.dart';
import 'views/debt_book_view.dart';
import 'views/auth_gate.dart';

void main() async {
  // Ensure native bindings are attached before running any plugin calls
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization non-fatal warning: $e");
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
  final SmsParserService _smsService = SmsParserService();
  String _storeTillNumber = '';
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _initSmsListener();
  }

  void _loadLocalData() async {
    try {
      final prodData = await LocalDbService.instance.getProducts();
      final saleData = await LocalDbService.instance.getSales();
      if (!mounted) return;
      setState(() {
        _products.clear();
        _products.addAll(prodData.map((e) => Product.fromMap(e)));
        _sales.clear();
        _sales.addAll(saleData.map((e) => SaleTransaction.fromMap(e)));
      });
    } catch (e) {
      debugPrint("LocalDb Service initialization error: $e");
    }
  }

  void _initSmsListener() async {
    try {
      bool granted = await _smsService.requestSmsPermissions();
      if (!granted || !mounted) return;
      _smsService.startListening(
        storeTillNumber: _storeTillNumber,
        currentSales: _sales,
        onPaymentDetected: (payment) {
          if (!mounted) return;
          String? matchedCode;
          double? matchedAmount;
          setState(() {
            for (var sale in _sales) {
              if (!sale.isPaid && sale.totalAmount == payment.amount) {
                sale.isPaid = true;
                sale.mpesaCode = payment.code;
                LocalDbService.instance.markSalePaid(sale.id, payment.code);
                matchedCode = payment.code;
                matchedAmount = payment.amount;
                break;
              }
            }
          });
          // Safely trigger SnackBar outside the rebuild loop
          if (matchedCode != null && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text(
                      'Auto-Matched M-Pesa Code $matchedCode for KES $matchedAmount!',
                    ),
                  ),
                );
              }
            });
          }
        },
        onDebtAutoCleared: (saleId, mpesaCode) {
          if (!mounted) return;
          setState(() {
            int idx = _sales.indexWhere((s) => s.id == saleId);
            if (idx >= 0) {
              _sales[idx].isPaid = true;
              _sales[idx].mpesaCode = mpesaCode;
              LocalDbService.instance.markSalePaid(saleId, mpesaCode);
            }
          });
        },
        onSubscriptionUpdated: (subscribed, expiry) {
          if (!mounted) return;
          setState(() {
            _isSubscribed = subscribed;
          });
        },
      );
    } catch (e) {
      debugPrint("SMS Listener permission or runtime error: $e");
    }
  }

  void _switchToDebtorsTab() {
    if (mounted) {
      setState(() {
        _currentIndex = 3;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      DashboardView(sales: _sales),
      PosView(
        products: _products,
        onSaleCompleted: (sale) {
          if (mounted) {
            setState(() => _sales.add(sale));
          }
        },
        onCreditSelected: _switchToDebtorsTab,
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
        onDebtCleared: (saleId, mpesaCode) {
          if (mounted) {
            setState(() {
              int idx = _sales.indexWhere((s) => s.id == saleId);
              if (idx >= 0) {
                _sales[idx].isPaid = true;
                _sales[idx].mpesaCode = mpesaCode;
              }
            });
          }
        },
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
