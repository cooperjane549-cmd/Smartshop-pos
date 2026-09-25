import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  final nameController = TextEditingController();
  final buyingPriceController = TextEditingController();
  final sellingPriceController = TextEditingController();
  final stockController = TextEditingController();
  final searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    nameController.dispose();
    buyingPriceController.dispose();
    sellingPriceController.dispose();
    stockController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // Get user's Firestore product collection reference
  CollectionReference? get _productsCollection {
    if (_user == null) return null;
    return _firestore.collection('users').doc(_user!.uid).collection('products');
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
                  sellingPriceController.text.isNotEmpty &&
                  _productsCollection != null) {
                final docId = DateTime.now().millisecondsSinceEpoch.toString();
                final product = Product(
                  id: docId,
                  name: nameController.text.trim(),
                  buyingPrice: double.parse(buyingPriceController.text.isEmpty
                      ? '0'
                      : buyingPriceController.text.trim()),
                  sellingPrice: double.parse(sellingPriceController.text.trim()),
                  stockQuantity: int.parse(stockController.text.isEmpty
                      ? '0'
                      : stockController.text.trim()),
                );

                // Save directly to Firestore
                await _productsCollection!.doc(docId).set(product.toMap());

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
                  sellingPriceController.text.isNotEmpty &&
                  _productsCollection != null) {
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

                // Update directly on Firestore
                await _productsCollection!.doc(product.id).update(updatedProduct.toMap());

                if (widget.onProductUpdated != null) {
                  widget.onProductUpdated!(updatedProduct);
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
              if (_productsCollection != null) {
                // Delete directly from Firestore
                await _productsCollection!.doc(product.id).delete();
              }

              if (widget.onProductDeleted != null) {
                widget.onProductDeleted!(product.id);
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
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search product by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _productsCollection?.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No inventory added yet.'));
                }

                final productsList = snapshot.data!.docs.map((doc) {
                  return Product.fromMap(doc.data() as Map<String, dynamic>);
                }).where((item) {
                  if (_searchQuery.isEmpty) return true;
                  return item.name.toLowerCase().contains(_searchQuery);
                }).toList();

                if (productsList.isEmpty) {
                  return const Center(child: Text('No items match your search.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: productsList.length,
                  itemBuilder: (context, index) {
                    final item = productsList[index];
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

