import 'dart0000000:json';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../services/local_db_service.dart';

class CartItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 1,
      unitPrice: (map['unitPrice'] as num).toDouble(),
    );
  }
}

class SaleTransaction {
  final String id;
  final double totalAmount;
  final String paymentMethod; // "CASH", "MPESA", "CREDIT"
  bool isPaid;
  final List<CartItem> items;
  final String customerName;
  final String customerPhone;
  final DateTime? dueDate;
  String mpesaCode;
  final DateTime createdAt;

  SaleTransaction({
    required this.id,
    required this.totalAmount,
    required this.paymentMethod,
    required this.isPaid,
    required this.items,
    this.customerName = '',
    this.customerPhone = '',
    this.dueDate,
    this.mpesaCode = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid ? 1 : 0,
      'items': jsonEncode(items.map((x) => x.toMap()).toList()),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'dueDate': dueDate?.toIso8601String(),
      'mpesaCode': mpesaCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map) {
    List<CartItem> parsedItems = [];
    if (map['items'] != null) {
      if (map['items'] is String) {
        final List dynamicList = jsonDecode(map['items']);
        parsedItems = dynamicList.map((x) => CartItem.fromMap(x)).toList();
      } else if (map['items'] is List) {
        parsedItems = (map['items'] as List).map((x) => CartItem.fromMap(x)).toList();
      }
    }

    return SaleTransaction(
      id: map['id'] ?? '',
      totalAmount: (map['totalAmount'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'CASH',
      isPaid: map['isPaid'] == 1 || map['isPaid'] == true,
      items: parsedItems,
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      mpesaCode: map['mpesaCode'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }

  /// Deducts sold item quantities from both Firestore and Local DB for all current products.
  Future<void> processStockDeduction(List<Product> availableProducts) async {
    final user = FirebaseAuth.instance.currentUser;

    for (final cartItem in items) {
      final int productIdx = availableProducts.indexWhere((p) => p.id == cartItem.productId);
      
      if (productIdx != -1) {
        final product = availableProducts[productIdx];
        final int newStock = (product.stockQuantity - cartItem.quantity) < 0 
            ? 0 
            : product.stockQuantity - cartItem.quantity;

        // Update local object memory
        product.stockQuantity = newStock;

        // Update local SQLite DB
        await LocalDbService.instance.updateStock(product.id, newStock);

        // Update Cloud Firestore
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .doc(product.id)
              .update({'stockQuantity': newStock});
        }
      }
    }
  }
}
