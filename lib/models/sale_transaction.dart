import 'dart:convert';

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
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      quantity: (map['quantity'] is num)
          ? (map['quantity'] as num).toInt()
          : int.tryParse(map['quantity']?.toString() ?? '1') ?? 1,
      unitPrice: (map['unitPrice'] is num)
          ? (map['unitPrice'] as num).toDouble()
          : double.tryParse(map['unitPrice']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class SaleTransaction {
  final String id;
  final double totalAmount;
  final String paymentMethod;
  bool isPaid;
  final List<CartItem> items;
  final String customerName;
  final String customerPhone;
  final DateTime? dueDate;
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
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map) {
    List<CartItem> parsedItems = [];
    if (map['items'] != null) {
      if (map['items'] is String) {
        try {
          final List<dynamic> decodedList = jsonDecode(map['items']);
          parsedItems = decodedList.map((e) => CartItem.fromMap(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      } else if (map['items'] is List) {
        parsedItems = (map['items'] as List)
            .map((e) => CartItem.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    }

    DateTime parsedCreatedAt;
    if (map['createdAt'] != null) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime? parsedDueDate;
    if (map['dueDate'] != null) {
      parsedDueDate = DateTime.tryParse(map['dueDate'].toString());
    }

    bool paidStatus = false;
    if (map['isPaid'] != null) {
      if (map['isPaid'] is bool) {
        paidStatus = map['isPaid'];
      } else if (map['isPaid'] is num) {
        paidStatus = map['isPaid'] == 1;
      } else if (map['isPaid'] is String) {
        paidStatus = map['isPaid'] == '1' || map['isPaid'].toString().toLowerCase() == 'true';
      }
    }

    return SaleTransaction(
      id: map['id']?.toString() ?? '',
      totalAmount: (map['totalAmount'] is num)
          ? (map['totalAmount'] as num).toDouble()
          : double.tryParse(map['totalAmount']?.toString() ?? '0') ?? 0.0,
      paymentMethod: map['paymentMethod']?.toString() ?? 'CASH',
      isPaid: paidStatus,
      items: parsedItems,
      customerName: map['customerName']?.toString() ?? '',
      customerPhone: map['customerPhone']?.toString() ?? '',
      dueDate: parsedDueDate,
      createdAt: parsedCreatedAt,
    );
  }
}
