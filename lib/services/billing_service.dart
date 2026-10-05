import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Google Play Billing via the in_app_purchase package. Products must
/// be created in Play Console → Monetize → Subscriptions with exactly
/// these IDs before this will return real data.
///
/// NOTE: this performs client-side confirmation only — it trusts the
/// PurchaseDetails Flutter receives directly from Play Billing and updates
/// Firestore accordingly. Server-side receipt verification (via a Cloud
/// Function + Play Developer API) is a recommended future hardening step,
/// not implemented here, to keep initial launch simpler.
class BillingService {
  static final BillingService instance = BillingService._internal();
  BillingService._internal();

  static const Set<String> productIds = {
    'smartshop_pro_1m',
    'smartshop_pro_3m',
    'smartshop_pro_6m',
    'smartshop_pro_12m',
  };

  static const Map<String, int> productDurationDays = {
    'smartshop_pro_1m': 30,
    'smartshop_pro_3m': 90,
    'smartshop_pro_6m': 180,
    'smartshop_pro_12m': 365,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> products = [];

  /// Call once at app startup. Begins listening for purchase results.
  void initialize() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        // Swallow — a failed stream shouldn't crash the app.
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Fetches the 4 subscription products with their real, localized prices
  /// from Play Store. Call before showing the upgrade dialog.
  Future<List<ProductDetails>> loadProducts() async {
    final available = await isAvailable();
    if (!available) {
      products = [];
      return products;
    }

    final response = await _iap.queryProductDetails(productIds);
    products = response.productDetails;
    return products;
  }

  /// Launches the native Play Billing purchase flow for the given product.
  Future<void> purchase(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _grantSubscription(purchase.productID);

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _grantSubscription(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final days = productDurationDays[productId];
    if (days == null) return;

    final firestore = FirebaseFirestore.instance;
    final subRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscription')
        .doc('status');

    final subDoc = await subRef.get();
    DateTime baseDate = DateTime.now();
    if (subDoc.exists) {
      final data = subDoc.data();
      final currentExpiry = data?['expiryDate'] as Timestamp?;
      if (currentExpiry != null && currentExpiry.toDate().isAfter(baseDate)) {
        baseDate = currentExpiry.toDate();
      }
    }

    final newExpiry = baseDate.add(Duration(days: days));

    await subRef.set({
      'isSubscribed': true,
      'expiryDate': Timestamp.fromDate(newExpiry),
      'lastPurchaseProductId': productId,
      'lastPurchaseAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
