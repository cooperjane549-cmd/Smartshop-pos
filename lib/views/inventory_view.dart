import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/local_db_service.dart';
import '../services/firebase_service.dart';

class InventoryView extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onProductAdded;
  final Function(Product)? onProductUpdated;
  final Function(String)? onProductDeleted;

  const InventoryView({
    Key? key,
    required this.products,
    required this.onProductAdded,
    this.onProductUpdated,
    this.onProductDeleted,
  }) : super(key: key);

  @override
  _InventoryViewState createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final nameController = TextEditingController();
  final buyingPriceController = TextEditingController();
  final sellingPriceController = TextEditingController();
  final stockController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    buyingPriceController.dispose();
    sellingPriceController.dispose();
    stockController.dispose();
    super.dispose();
  }

  void _showAddProductDialog() {
    nameController.clear();
    buyingPriceController.clear();
    sellingPriceController.clear();
    stockController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product to Stock'),
        content: SingleChildScrollView(
          child: Column(
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
                  name: nameController.text.trim(),
                  buyingPrice: double.parse(buyingPriceController.text.isEmpty
                      ? '0'
                      : buyingPriceController.text.trim()),
                  sellingPrice: double.parse(sellingPriceController.text.trim()),
                  stockQuantity: int.parse(stockController.text.isEmpty
                      ? '0'
                      : stockController.text.trim()),
                );

                await LocalDbService.instance.insertProduct(product.toMap());
                FirebaseService().syncProduct(product);

                widget.onProductAdded(product);

                if (!mounted) return;
                Navigator.pop(context);
              }
            },
            child: const Text('Save Stock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    nameController.text = product.name;
    buyingPriceController.text = product.buyingPrice.toStringAsFixed(0);
    sellingPriceController.text = product.sellingPrice.toStringAsFixed(0);
    stockController.text = product.stockQuantity.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${product.name}'),
        content: SingleChildScrollView(
          child: Column(
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
                decoration: const InputDecoration(labelText: 'Stock Quantity'),
              ),
            ],
          ),
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
                final updatedProduct = Product(
                  id: product.id,
                  name: nameController.text.trim(),
                  buyingPrice: double.parse(buyingPriceController.text.isEmpty
                      ? '0'
                      : buyingPriceController.text.trim()),
                  sellingPrice: double.parse(sellingPriceController.text.trim()),
                  stockQuantity: int.parse(stockController.text.isEmpty
                      ? '0'
                      : stockController.text.trim()),
                  lowStockAlertThreshold: product.lowStockAlertThreshold,
                );

                await LocalDbService.instance.insertProduct(updatedProduct.toMap());
                FirebaseService().syncProduct(updatedProduct);

                if (widget.onProductUpdated != null) {
                  widget.onProductUpdated!(updatedProduct);
                } else {
                  setState(() {
                    int index = widget.products.indexWhere((p) => p.id == product.id);
                    if (index != -1) widget.products[index] = updatedProduct;
                  });
                }

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product updated successfully!')),
                );
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}" from inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await LocalDbService.instance.deleteProduct(product.id);
              if (widget.onProductDeleted != null) {
                widget.onProductDeleted!(product.id);
              } else {
                setState(() {
                  widget.products.removeWhere((p) => p.id == product.id);
                });
              }
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product deleted.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Stock: ${item.stockQuantity} units | Buy: KES ${item.buyingPrice.toStringAsFixed(0)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KES ${item.sellingPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.indigo),
                          onPressed: () => _showEditProductDialog(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeleteProduct(item),
                        ),
                      ],
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
