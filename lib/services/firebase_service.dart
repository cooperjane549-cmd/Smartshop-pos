import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../models/sale_transaction.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Future<void> syncProduct(Product product) async {
    if (currentUid == null) return;
    await _db
        .collection('users')
        .doc(currentUid)
        .collection('products')
        .doc(product.id)
        .set(product.toMap());
  }

  Future<void> syncSale(SaleTransaction sale) async {
    if (currentUid == null) return;
    await _db
        .collection('users')
        .doc(currentUid)
        .collection('sales')
        .doc(sale.id)
        .set(sale.toMap());
  }

  Future<DocumentSnapshot?> getSubscriptionStatus() async {
    if (currentUid == null) return null;
    return await _db.collection('users').doc(currentUid).get();
  }
}
