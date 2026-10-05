import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../models/product.dart';
import '../models/sale_transaction.dart';
import '../services/local_db_service.dart';
import '../services/firebase_service.dart';
import '../services/shop_profile_service.dart';
import '../services/currency_service.dart';
import 'receipt_view.dart';

class PosView extends StatefulWidget {
  final List<Product> products;
  final List<SaleTransaction> sales;
  final Function(SaleTransaction) onSaleCompleted;
  final VoidCallback? onCreditSelected;
  final Function(String saleId, double addedAmount, List<CartItem> addedItems)?
      onExistingDebtFound;

  const PosView({
    Key? key,
    required this.products,
    required this.sales,
    required this.onSaleCompleted,
    this.onCreditSelected,
    this.onExistingDebtFound,
  }) : super(key: key);

  @override
  _PosViewState createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final List<CartItem> _cart = [];
  String _paymentMethod = 'CASH';
  final _shopNameController = TextEditingController(text: 'SmartShop');
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDueDate;

  String get _currency => CurrencyService.symbol;

  @override
  void initState() {
    super.initState();
    _loadPersistedShopName();
  }

  Future<void> _loadPersistedShopName() async {
    final savedName = await ShopProfileService.instance.getShopName();
    if (mounted) {
      setState(() => _shopNameController.text = savedName);
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(Product p) {
    if (p.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item out of stock!')),
      );
      return;
    }

    int idx = _cart.indexWhere((c) => c.productId == p.id);
    int currentInCart = idx >= 0 ? _cart[idx].quantity : 0;

    if (currentInCart >= p.stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot add more. Available stock is ${p.stockQuantity}'),
        ),
      );
      return;
    }

    setState(() {
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

  String _normalizePhone(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0') && cleaned.length > 1) {
      cleaned = '254${cleaned.substring(1)}';
    }
    return cleaned;
  }

  Future<SaleTransaction?> _resolveDebtorMatch(String phone) async {
    final normalizedInput = _normalizePhone(phone);
    if (normalizedInput.isEmpty) return null;

    SaleTransaction? existing;
    for (var s in widget.sales) {
      if (s.paymentMethod == 'CREDIT' && !s.isPaid && s.totalAmount > 0) {
        if (_normalizePhone(s.customerPhone) == normalizedInput) {
          existing = s;
          break;
        }
      }
    }

    if (existing == null) return null;

    final matchedSale = existing;
    final newTotal = matchedSale.totalAmount + cartTotal;

    if (!mounted) return null;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        title: const Text('Existing Debt Found'),
        content: Text(
          '${matchedSale.customerName.isEmpty ? "This customer" : matchedSale.customerName} '
          'already owes $_currency ${matchedSale.totalAmount.toStringAsFixed(0)}.\n\n'
          'Add this purchase of $_currency ${cartTotal.toStringAsFixed(0)} to their existing debt?\n'
          'New total will be $_currency ${newTotal.toStringAsFixed(0)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('No, New Debtor'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Yes, Add to Existing',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return (confirmed == true) ? matchedSale : null;
  }

  Future<void> _deductStockForCartItems() async {
    final user = FirebaseAuth.instance.currentUser;

    for (var cartItem in _cart) {
      if (user != null) {
        final productRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .doc(cartItem.productId);

        try {
          await productRef.update({
            'stockQuantity': FieldValue.increment(-cartItem.quantity),
          });

          final updatedDoc = await productRef.get();
          final newQty = (updatedDoc.data()?['stockQuantity'] ?? 0) as int;
          final safeQty = newQty < 0 ? 0 : newQty;

          if (safeQty != newQty) {
            await productRef.update({'stockQuantity': safeQty});
          }

          await LocalDbService.instance.updateStock(cartItem.productId, safeQty);

          int pIdx = widget.products.indexWhere((p) => p.id == cartItem.productId);
          if (pIdx >= 0) {
            widget.products[pIdx].stockQuantity = safeQty;
          }
        } catch (e) {
          debugPrint("Error deducting stock for ${cartItem.productId}: $e");
        }
      } else {
        int pIdx = widget.products.indexWhere((p) => p.id == cartItem.productId);
        if (pIdx >= 0) {
          final newQuantity = widget.products[pIdx].stockQuantity - cartItem.quantity;
          final updatedStock = newQuantity < 0 ? 0 : newQuantity;

          widget.products[pIdx].stockQuantity = updatedStock;

          await LocalDbService.instance.updateStock(
            widget.products[pIdx].id,
            updatedStock,
          );
        }
      }
    }
  }

  void _showCheckoutDialog() {
    if (_cart.isEmpty) return;

    final isCredit = _paymentMethod == 'CREDIT';
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                isCredit
                    ? 'Credit Sale Details (Mkopo)'
                    : 'Sale Details ($_paymentMethod)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerNameController,
                      decoration: InputDecoration(
                        labelText: isCredit
                            ? 'Customer Name *'
                            : 'Customer Name (Optional)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isCredit
                            ? 'Customer Phone *'
                            : 'Customer Phone (Optional)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Text(
                            'Purchase Date: $formattedDate',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (isCredit) ...[
                      const SizedBox(height: 10),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: Text(
                          _selectedDueDate == null
                              ? 'Select Payment Due Date *'
                              : 'Due Date: ${_selectedDueDate.toString().split(' ')[0]}',
                        ),
                        trailing: const Icon(Icons.event, color: Colors.orange),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setModalState(() {
                              _selectedDueDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                  ),
                  onPressed: () async {
                    if (_shopNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a shop name.')),
                      );
                      return;
                    }

                    if (isCredit) {
                      if (_customerNameController.text.trim().isEmpty ||
                          _customerPhoneController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please fill customer name and phone for credit sale.')),
                        );
                        return;
                      }
                      if (_selectedDueDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please select a payment due date.')),
                        );
                        return;
                      }

                      final existingDebtor = await _resolveDebtorMatch(
                          _customerPhoneController.text.trim());

                      if (!mounted) return;
                      Navigator.pop(ctx);

                      if (existingDebtor != null) {
                        _completeCreditMerge(existingDebtor);
                      } else {
                        _completeCheckout();
                      }
                    } else {
                      Navigator.pop(ctx);
                      _completeCheckout();
                    }
                  },
                  child: Text(
                    isCredit ? 'Save Credit Sale' : 'Complete Sale',
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

  void _completeCreditMerge(SaleTransaction existingSale) async {
    if (_cart.isEmpty) return;

    await _deductStockForCartItems();

    final addedItems = List<CartItem>.from(_cart);
    final addedAmount = cartTotal;

    widget.onExistingDebtFound?.call(existingSale.id, addedAmount, addedItems);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stock updated. Confirm adding $_currency ${addedAmount.toStringAsFixed(0)} '
          'to ${existingSale.customerName}\'s balance on the Debtors screen.',
        ),
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

  void _completeCheckout() async {
    if (_cart.isEmpty) return;

    await _deductStockForCartItems();

    final phone = _customerPhoneController.text.trim();
    final customerName = _customerNameController.text.trim();
    final shopName = _shopNameController.text.trim();

    final sale = SaleTransaction(
      id: 'SALE_${DateTime.now().millisecondsSinceEpoch}',
      totalAmount: cartTotal,
      paymentMethod: _paymentMethod,
      isPaid: _paymentMethod != 'CREDIT',
      items: List.from(_cart),
      customerName: customerName,
      customerPhone: phone,
      dueDate: _selectedDueDate,
      createdAt: DateTime.now(),
    );

    Map<String, dynamic> saleMap = sale.toMap();
    saleMap['items'] = jsonEncode(sale.items.map((e) => e.toMap()).toList());
    await LocalDbService.instance.insertSale(saleMap);

    await FirebaseService().syncSale(sale);

    widget.onSaleCompleted(sale);

    if (phone.isNotEmpty) {
      _sendWhatsAppReceipt(
        phone: phone,
        customerName: customerName,
        shopName: shopName,
        sale: sale,
      );
    }

    await ShopProfileService.instance.setShopName(shopName);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptView(sale: sale, shopName: shopName),
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

  void _sendWhatsAppReceipt({
    required String phone,
    required String customerName,
    required String shopName,
    required SaleTransaction sale,
  }) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '254${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }

    final dateStr =
        "${sale.createdAt.year}-${sale.createdAt.month.toString().padLeft(2, '0')}-${sale.createdAt.day.toString().padLeft(2, '0')}";

    StringBuffer itemList = StringBuffer();
    for (var item in sale.items) {
      itemList.writeln(
          "- ${item.productName} x${item.quantity} = $_currency ${(item.quantity * item.unitPrice).toStringAsFixed(0)}");
    }

    String message;
    if (sale.paymentMethod == 'CREDIT') {
      final dueDateStr = sale.dueDate != null
          ? "${sale.dueDate!.year}-${sale.dueDate!.month.toString().padLeft(2, '0')}-${sale.dueDate!.day.toString().padLeft(2, '0')}"
          : 'N/A';

      message = "🧾 *CREDIT RECEIPT - $shopName*\n"
          "------------------------------------\n"
          "Customer: ${customerName.isEmpty ? 'Valued Customer' : customerName}\n"
          "Date: $dateStr\n"
          "Payment Due Date: $dueDateStr\n\n"
          "*Items Bought:*\n"
          "${itemList.toString()}\n"
          "*Total Amount Due: $_currency ${sale.totalAmount.toStringAsFixed(0)}*\n"
          "------------------------------------\n"
          "Please clear your payment on or before $dueDateStr. Thank you for doing business with $shopName!";
    } else {
      message = "🧾 *RECEIPT - $shopName*\n"
          "------------------------------------\n"
          "Customer: ${customerName.isEmpty ? 'Valued Customer' : customerName}\n"
          "Date: $dateStr\n"
          "Payment Method: ${sale.paymentMethod}\n\n"
          "*Items Bought:*\n"
          "${itemList.toString()}\n"
          "*Total Paid: $_currency ${sale.totalAmount.toStringAsFixed(0)}*\n"
          "------------------------------------\n"
          "Thank you for shopping at $shopName!";
    }

    final uri = Uri.parse(
        "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Sell Screen'),
        backgroundColor: Colors.indigo,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search items to sell...',
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: user == null
                      ? _buildProductList(widget.products)
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('products')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            List<Product> products = widget.products;
                            if (snapshot.hasData &&
                                snapshot.data!.docs.isNotEmpty) {
                              products = snapshot.data!.docs.map((doc) {
                                return Product.fromMap(
                                    doc.data() as Map<String, dynamic>);
                              }).toList();
                            }

                            return _buildProductList(products);
                          },
                        ),
                ),
              ],
            ),
          ),
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
                                  '$_currency ${(item.quantity * item.unitPrice).toStringAsFixed(0)}',
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
                        '$_currency ${cartTotal.toStringAsFixed(0)}',
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
                          onSelected: (s) {
                            setState(() => _paymentMethod = 'CASH');
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('OTHER')),
                          selected: _paymentMethod == 'OTHER',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (s) {
                            setState(() => _paymentMethod = 'OTHER');
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('CREDIT')),
                          selected: _paymentMethod == 'CREDIT',
                          selectedColor: Colors.orange.shade100,
                          onSelected: (s) {
                            setState(() => _paymentMethod = 'CREDIT');
                            if (_cart.isNotEmpty) {
                              _showCheckoutDialog();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                      onPressed: _cart.isEmpty
                          ? null
                          : () {
                              _showCheckoutDialog();
                            },
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

  Widget _buildProductList(List<Product> products) {
    final filteredProducts = products.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredProducts.isEmpty) {
      return const Center(
        child: Text('No items match your search.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredProducts.length,
      itemBuilder: (context, idx) {
        final p = filteredProducts[idx];
        return _buildProductTile(p);
      },
    );
  }

  Widget _buildProductTile(Product p) {
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
          child: Text(
            '+ $_currency ${p.sellingPrice.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
