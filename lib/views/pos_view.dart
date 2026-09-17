import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/sale_transaction.dart';

class PosView extends StatefulWidget {
  final List<Product> products;
  final Function(SaleTransaction) onSaleCompleted;
  final VoidCallback onCreditSelected;

  const PosView({
    Key? key,
    required this.products,
    required this.onSaleCompleted,
    required this.onCreditSelected,
  }) : super(key: key);

  @override
  _PosViewState createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final Map<Product, int> _cart = {};
  String _selectedPaymentMode = 'CASH';

  double get _totalAmount {
    double sum = 0;
    _cart.forEach((product, qty) {
      sum += product.sellingPrice * qty;
    });
    return sum;
  }

  void _addToCart(Product product) {
    setState(() {
      _cart[product] = (_cart[product] ?? 0) + 1;
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product)) {
        if (_cart[product]! > 1) {
          _cart[product] = _cart[product]! - 1;
        } else {
          _cart.remove(product);
        }
      }
    });
  }

  void _checkout() {
    if (_cart.isEmpty) return;

    List<CartItem> items = [];
    _cart.forEach((product, qty) {
      items.add(CartItem(
        productName: product.name,
        quantity: qty,
        unitPrice: product.sellingPrice,
      ));
      product.stockQuantity -= qty;
    });

    final newSale = SaleTransaction(
      id: 'SALE_${DateTime.now().millisecondsSinceEpoch}',
      items: items,
      totalAmount: _totalAmount,
      paymentMode: _selectedPaymentMode,
      isPaid: true,
      timestamp: DateTime.now(),
    );

    widget.onSaleCompleted(newSale);

    setState(() {
      _cart.clear();
      _selectedPaymentMode = 'CASH';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('Sale Completed via $_selectedPaymentMode!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Register'),
        backgroundColor: Colors.indigo,
      ),
      body: Row(
        children: [
          // Left Side: Product Selector
          Expanded(
            flex: 5,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: widget.products.length,
              itemBuilder: (context, index) {
                final product = widget.products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Stock: ${product.stockQuantity}'),
                    trailing: ElevatedButton(
                      onPressed: () => _addToCart(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                      child: Text('+ KES ${product.sellingPrice.toStringAsFixed(0)}'),
                    ),
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          // Right Side: Cart Summary & Payment
          Expanded(
            flex: 6,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Current Cart',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(child: Text('No items in cart'))
                      : ListView.builder(
                          itemCount: _cart.keys.length,
                          itemBuilder: (context, idx) {
                            final product = _cart.keys.elementAt(idx);
                            final qty = _cart[product]!;
                            final subtotal = product.sellingPrice * qty;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'x$qty @ KES ${product.sellingPrice.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'KES ${subtotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeFromCart(product),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'KES ${_totalAmount.toStringAsFixed(0)}',
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
                              selected: _selectedPaymentMode == 'CASH',
                              selectedColor: Colors.indigo.shade100,
                              onSelected: (val) {
                                setState(() => _selectedPaymentMode = 'CASH');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('M-PESA')),
                              selected: _selectedPaymentMode == 'M-PESA',
                              selectedColor: Colors.indigo.shade100,
                              onSelected: (val) {
                                setState(() => _selectedPaymentMode = 'M-PESA');
                              },
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
                          style: TextStyle(color: Colors.orange),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          minimumSize: const Size.fromHeight(40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _cart.isNotEmpty ? _checkout : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                          ),
                          child: const Text(
                            'Complete & Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
