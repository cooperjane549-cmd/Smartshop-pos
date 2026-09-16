class Customer {
  final String id;
  final String name;
  final String phone;
  double totalOutstandingDebt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalOutstandingDebt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'totalOutstandingDebt': totalOutstandingDebt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      totalOutstandingDebt: (map['totalOutstandingDebt'] as num).toDouble(),
    );
  }
}
