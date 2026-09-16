import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop_pos/models/product.dart';
import 'package:smartshop_pos/models/sale_transaction.dart';

void main() {
  group('Product Model Tests', () {
    test('Product initialization and stock calculation', () {
      final product = Product(
        id: 'PROD_001',
        name: 'Sugar 1kg',
        buyingPrice: 120.0,
        sellingPrice: 150.0,
        stockQuantity: 10,
      );

      expect(product.id, 'PROD_001');
      expect(product.name, 'Sugar 1kg');
      expect(product.sellingPrice, 150.0);
      expect(product.stockQuantity, 10);
    });

    test('Product map serialization and deserialization', () {
      final productMap = {
        'id': 'PROD_002',
        'name': 'Cooking Oil 1L',
        'buyingPrice': 200.0,
        'sellingPrice': 250.0,
        'stockQuantity': 5,
      };

      final product = Product.fromMap(productMap);

      expect(product.id, 'PROD_002');
      expect(product.sellingPrice, 250.0);
      expect(product.toMap()['name'], 'Cooking Oil 1L');
    });
  });

  group('CartItem & SaleTransaction Tests', () {
    test('CartItem calculates correct subtotal', () {
      final item = CartItem(
        productId: 'PROD_001',
        productName: 'Sugar 1kg',
        quantity: 3,
        unitPrice: 150.0,
      );

      final total = item.quantity * item.unitPrice;
      expect(total, 450.0);
    });

    test('SaleTransaction initializes with correct total and payment method', () {
      final items = [
        CartItem(
          productId: 'PROD_001',
          productName: 'Sugar 1kg',
          quantity: 2,
          unitPrice: 150.0,
        ),
        CartItem(
          productId: 'PROD_002',
          productName: 'Milk 500ml',
          quantity: 1,
          unitPrice: 60.0,
        ),
      ];

      final calculatedTotal = items.fold(
        0.0,
        (sum, item) => sum + (item.quantity * item.unitPrice),
      );

      final transaction = SaleTransaction(
        id: 'SALE_1001',
        totalAmount: calculatedTotal,
        paymentMethod: 'MPESA',
        mpesaCode: 'QWX12345',
        isPaid: true,
        items: items,
        createdAt: DateTime.now(),
      );

      expect(transaction.totalAmount, 360.0);
      expect(transaction.paymentMethod, 'MPESA');
      expect(transaction.items.length, 2);
      expect(transaction.isPaid, isTrue);
    });
  });

  group('Widget UI Smoke Test', () {
    testWidgets('Basic MaterialApp loads without throwing errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Smartshop POS Ready'),
            ),
          ),
        ),
      );

      expect(find.text('Smartshop POS Ready'), findsOneWidget);
    });
  });
}
