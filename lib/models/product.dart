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
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      buyingPrice: (map['buyingPrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      stockQuantity: map['stockQuantity'] ?? 0,
      lowStockAlertThreshold: map['lowStockAlertThreshold'] ?? 5,
    );
  }
}
