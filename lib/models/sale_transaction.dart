class SaleItem {
  final String productName;
  final int quantity;
  final double unitPrice;

  SaleItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SaleTransaction {
  final String id;
  final double totalAmount;
  final String paymentMethod; // CASH, MPESA, CREDIT
  final bool isPaid;
  final List<SaleItem> items;
  final String? customerName;
  final String? customerPhone;
  final DateTime? dueDate;
  final DateTime createdAt;

  SaleTransaction({
    required this.id,
    required this.totalAmount,
    required this.paymentMethod,
    required this.isPaid,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.dueDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid,
      'items': items.map((x) => x.toMap()).toList(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map) {
    return SaleTransaction(
      id: map['id'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? 'CASH',
      isPaid: map['isPaid'] ?? true,
      items: (map['items'] as List<dynamic>?)
              ?.map((x) => SaleItem.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
      customerName: map['customerName'],
      customerPhone: map['customerPhone'],
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
