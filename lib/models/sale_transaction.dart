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
      'items': items.map((x) => x.toMap()).toList(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'dueDate': dueDate?.toIso8601String(),
      'mpesaCode': mpesaCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map) {
    return SaleTransaction(
      id: map['id'] ?? '',
      totalAmount: (map['totalAmount'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'CASH',
      isPaid: map['isPaid'] == 1 || map['isPaid'] == true,
      items: map['items'] != null
          ? List<CartItem>.from(
              (map['items'] as List).map((x) => CartItem.fromMap(x)))
          : [],
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      mpesaCode: map['mpesaCode'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
