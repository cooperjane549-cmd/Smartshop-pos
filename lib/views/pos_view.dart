import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _shopNameController = TextEditingController(text: 'SmartShop');
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDueDate;

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
                    : ' Sale Details ($_paymentMethod)',
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
                  onPressed: () {
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
                    }

                    Navigator.pop(ctx);
                    _completeCheckout();
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

  void _completeCheckout() async {
    if (_cart.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    // Deduct stock locally & via database
    for (var cartItem in _cart) {
      int pIdx = widget.products.indexWhere((p) => p.id == cartItem.productId);
      if (pIdx >= 0) {
        widget.products[pIdx].stockQuantity -= cartItem.quantity;
        await LocalDbService.instance.updateStock(
          widget.products[pIdx].id,
          widget.products[pIdx].stockQuantity,
        );

        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .doc(widget.products[pIdx].id)
              .update({'stockQuantity': widget.products[pIdx].stockQuantity});
        }
      }
    }

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

    // Save to local database for offline resilience
    Map<String, dynamic> saleMap = sale.toMap();
    saleMap['items'] = jsonEncode(sale.items.map((e) => e.toMap()).toList());
    await LocalDbService.instance.insertSale(saleMap);

    // Persist permanently to Cloud Firestore
    await FirebaseService().syncSale(sale);

    // Notify parent hub
    widget.onSaleCompleted(sale);

    // Send WhatsApp receipt/nudge if phone number is present
    if (phone.isNotEmpty) {
      _sendWhatsAppReceipt(
        phone: phone,
        customerName: customerName,
        shopName: shopName,
        sale: sale,
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
          "- ${item.productName} x${item.quantity} = KES ${(item.quantity * item.unitPrice).toStringAsFixed(0)}");
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
          "*Total Amount Due: KES ${sale.totalAmount.toStringAsFixed(0)}*\n"
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
          "*Total Paid: KES ${sale.totalAmount.toStringAsFixed(0)}*\n"
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
          // Left: Search Bar & Product Catalog from Firestore
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
                          onSelected: (s) {
                            setState(() => _paymentMethod = 'CASH');
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('M-PESA')),
                          selected: _paymentMethod == 'MPESA',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (s) {
                            setState(() => _paymentMethod = 'MPESA');
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
            '+ KES ${p.sellingPrice.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
