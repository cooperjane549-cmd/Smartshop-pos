import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../models/product.dart';
import '../models/sale_transaction.dart';
import '../services/local_db_service.dart';
import '../services/firebase_service.dart';
import 'receipt_view.dart';

class PosView extends StatefulWidget {
  final List<Product> products;
  final Function(SaleTransaction) onSaleCompleted;
  final VoidCallback? onCreditSelected;

  const PosView({
    Key? key,
    required this.products,
    required this.onSaleCompleted,
    this.onCreditSelected,
  }) : super(key: key);

  @override
  _PosViewState createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final List<CartItem> _cart = [];
  String _paymentMethod = 'CASH';
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  DateTime? _selectedDueDate;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  void _addToCart(Product p) {
    if (p.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item out of stock!')),
      );
      return;
    }
    setState(() {
      int idx = _cart.indexWhere((c) => c.productId == p.id);
      if (idx >= 0) {
        _cart[idx] = CartItem(
          productId: p.id,
          productName: p.name,
          quantity: _cart[idx].quantity + 1,
          unitPrice: p.sellingPrice,
        );
      } else {
        _cart.add(CartItem(
          productId: p.id,
          productName: p.name,
          quantity: 1,
          unitPrice: p.sellingPrice,
        ));
      }
    });
  }

  double get cartTotal =>
      _cart.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));

  void _completeCheckout() async {
    if (_cart.isEmpty) return;

    for (var cartItem in _cart) {
      int pIdx = widget.products.indexWhere((p) => p.id == cartItem.productId);
      if (pIdx >= 0) {
        widget.products[pIdx].stockQuantity -= cartItem.quantity;
        await LocalDbService.instance.updateStock(
          widget.products[pIdx].id,
          widget.products[pIdx].stockQuantity,
        );
      }
    }

    final sale = SaleTransaction(
      id: 'SALE_${DateTime.now().millisecondsSinceEpoch}',
      totalAmount: cartTotal,
      paymentMethod: _paymentMethod,
      isPaid: _paymentMethod != 'CREDIT',
      items: List.from(_cart),
      customerName: _customerNameController.text,
      customerPhone: _customerPhoneController.text,
      dueDate: _selectedDueDate,
      createdAt: DateTime.now(),
    );

    Map<String, dynamic> saleMap = sale.toMap();
    saleMap['items'] = jsonEncode(sale.items.map((e) => e.toMap()).toList());

    await LocalDbService.instance.insertSale(saleMap);
    FirebaseService().syncSale(sale);
    widget.onSaleCompleted(sale);

    if (_paymentMethod == 'CREDIT' &&
        _customerPhoneController.text.isNotEmpty) {
      _sendCreditWhatsAppNudge(
        _customerPhoneController.text,
        _customerNameController.text,
        cartTotal,
      );
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptView(sale: sale),
      ),
    );

    setState(() {
      _cart.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _selectedDueDate = null;
      _paymentMethod = 'CASH';
    });
  }

  void _sendCreditWhatsAppNudge(
      String phone, String name, double amount) async {
    final message =
        "Hello $name, this confirms your credit purchase of KES ${amount.toStringAsFixed(0)} at SmartShop POS. Please clear via M-Pesa at your earliest convenience.";
    final uri = Uri.parse(
        "https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Sell Screen'),
        backgroundColor: Colors.indigo,
      ),
      body: Row(
        children: [
          // Left: Product Catalog
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: widget.products.length,
              itemBuilder: (context, idx) {
                final p = widget.products[idx];
                return Card(
                  child: ListTile(
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Stock: ${p.stockQuantity}'),
                    trailing: ElevatedButton(
                      onPressed: () => _addToCart(p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                      child: Text('+ KES ${p.sellingPrice.toStringAsFixed(0)}'),
                    ),
                  ),
                );
              },
            ),
          ),
          // Right: Cart & Payment Details
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Cart',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('No items in cart'))
                        : ListView.builder(
                            itemCount: _cart.length,
                            itemBuilder: (context, idx) {
                              final item = _cart[idx];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  item.productName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('x${item.quantity}'),
                                trailing: Text(
                                  'KES ${(item.quantity * item.unitPrice).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'KES ${cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('CASH')),
                          selected: _paymentMethod == 'CASH',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (s) =>
                              setState(() => _paymentMethod = 'CASH'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('M-PESA')),
                          selected: _paymentMethod == 'MPESA',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (s) =>
                              setState(() => _paymentMethod = 'MPESA'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onCreditSelected,
                    icon: const Icon(Icons.book, color: Colors.orange),
                    label: const Text(
                      'CREDIT SALE (GO TO DEBTORS)',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                      onPressed: _cart.isEmpty ? null : _completeCheckout,
                      child: const Text(
                        'Complete & Receipt',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
