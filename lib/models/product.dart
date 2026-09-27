class Product {
  final String id;
  final String name;
  final double buyingPrice;
  final double sellingPrice;
  int stockQuantity;
  final int lowStockAlertThreshold;

  Product({
    required this.id,
    required this.name,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.lowStockAlertThreshold = 5,
  });

  Product copyWith({
    String? id,
    String? name,
    double? buyingPrice,
    double? sellingPrice,
    int? stockQuantity,
    int? lowStockAlertThreshold,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockAlertThreshold: lowStockAlertThreshold ?? this.lowStockAlertThreshold,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'buyingPrice': buyingPrice,
      'sellingPrice': sellingPrice,
      'stockQuantity': stockQuantity,
      'lowStockAlertThreshold': lowStockAlertThreshold,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      buyingPrice: (map['buyingPrice'] is num)
          ? (map['buyingPrice'] as num).toDouble()
          : double.tryParse(map['buyingPrice']?.toString() ?? '0') ?? 0.0,
      sellingPrice: (map['sellingPrice'] is num)
          ? (map['sellingPrice'] as num).toDouble()
          : double.tryParse(map['sellingPrice']?.toString() ?? '0') ?? 0.0,
      stockQuantity: (map['stockQuantity'] is num)
          ? (map['stockQuantity'] as num).toInt()
          : int.tryParse(map['stockQuantity']?.toString() ?? '0') ?? 0,
      lowStockAlertThreshold: (map['lowStockAlertThreshold'] is num)
          ? (map['lowStockAlertThreshold'] as num).toInt()
          : int.tryParse(map['lowStockAlertThreshold']?.toString() ?? '5') ?? 5,
    );
  }
}
