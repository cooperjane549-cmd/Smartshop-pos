import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Persists the shop's own display name (shown on receipts) so the cashier
/// only has to set it once instead of retyping it every sale.
class ShopProfileService {
  static final ShopProfileService instance = ShopProfileService._internal();
  ShopProfileService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference? get _userDocRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid);
  }

  Future<String> getShopName() async {
    final ref = _userDocRef;
    if (ref == null) return 'SmartShop';
    final doc = await ref.get();
    final data = doc.data() as Map<String, dynamic>?;
    final name = data?['shopName'] as String?;
    return (name != null && name.trim().isNotEmpty) ? name : 'SmartShop';
  }

  Future<void> setShopName(String name) async {
    final ref = _userDocRef;
    if (ref == null || name.trim().isEmpty) return;
    await ref.set({'shopName': name.trim()}, SetOptions(merge: true));
  }
}
