import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/local_db_service.dart';
import '../services/firebase_service.dart';

class InventoryView extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onProductAdded;

  const InventoryView({
    Key? key,
    required this.products,
    required this.onProductAdded,
  }) : super(key: key);

  @override
  _InventoryViewState createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final nameController = TextEditingController();
  final buyingPriceController = TextEditingController();
  final sellingPriceController = TextEditingController();
  final stockController = TextEditingController();

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product to Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            TextField(
              controller: buyingPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Buying Price (KES)'),
            ),
            TextField(
              controller: sellingPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Selling Price (KES)'),
            ),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Initial Quantity'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  sellingPriceController.text.isNotEmpty) {
                final product = Product(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  buyingPrice: double.parse(buyingPriceController.text.isEmpty
                      ? '0'
                      : buyingPriceController.text),
                  sellingPrice: double.parse(sellingPriceController.text),
                  stockQuantity: int.parse(stockController.text.isEmpty
                      ? '0'
                      : stockController.text),
                );

                await LocalDbService.instance.insertProduct(product.toMap());
                FirebaseService().syncProduct(product);

                widget.onProductAdded(product);

                nameController.clear();
                buyingPriceController.clear();
                sellingPriceController.clear();
                stockController.clear();

                Navigator.pop(context);
              }
            },
            child: const Text('Save Stock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock'),
        backgroundColor: Colors.indigo,
      ),
      body: widget.products.isEmpty
          ? const Center(child: Text('No inventory added yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.products.length,
              itemBuilder: (context, index) {
                final item = widget.products[index];
                bool isLowStock = item.stockQuantity <= item.lowStockAlertThreshold;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isLowStock ? Colors.red : Colors.indigo,
                      child: Icon(
                        isLowStock ? Icons.warning : Icons.inventory_2,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Stock: ${item.stockQuantity} units | Buy: KES ${item.buyingPrice.toStringAsFixed(0)}'),
                    trailing: Text(
                      'KES ${item.sellingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
