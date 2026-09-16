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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Falls back seamlessly if Firebase config json is pending setup
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
      ),
      home: const MainNavigationHub(),
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

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _initSmsListener();
  }

  void _loadLocalData() async {
    final prodData = await LocalDbService.instance.getProducts();
    final saleData = await LocalDbService.instance.getSales();

    setState(() {
      _products.clear();
      _products.addAll(prodData.map((e) => Product.fromMap(e)));

      _sales.clear();
      _sales.addAll(saleData.map((e) => SaleTransaction.fromMap(e)));
    });
  }

  void _initSmsListener() async {
    bool granted = await _smsService.requestSmsPermissions();
    if (granted) {
      _smsService.startListening((payment) {
        setState(() {
          for (var sale in _sales) {
            if (!sale.isPaid && sale.totalAmount == payment.amount) {
              sale.isPaid = true;
              sale.mpesaCode = payment.code;
              LocalDbService.instance.markSalePaid(sale.id, payment.code);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(
                      'Auto-Matched M-Pesa Code ${payment.code} for KES ${payment.amount}!'),
                ),
              );
              break;
            }
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      DashboardView(sales: _sales),
      PosView(
        products: _products,
        onSaleCompleted: (sale) => setState(() => _sales.add(sale)),
      ),
      InventoryView(
        products: _products,
        onProductAdded: (p) => setState(() => _products.add(p)),
      ),
      DebtBookView(
        sales: _sales,
        onDebtCleared: (saleId, mpesaCode) {
          setState(() {
            int idx = _sales.indexWhere((s) => s.id == saleId);
            if (idx >= 0) {
              _sales[idx].isPaid = true;
              _sales[idx].mpesaCode = mpesaCode;
            }
          });
        },
      ),
    ];

    return Scaffold(
      body: views[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Summary'),
          BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale), label: 'Register'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory), label: 'Stock'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book), label: 'Debtors'),
        ],
      ),
    );
  }
}
