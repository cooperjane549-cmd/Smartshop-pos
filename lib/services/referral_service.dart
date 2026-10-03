import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles referral code generation, linking a new user to their referrer,
/// and granting a free 30-day Pro extension once a referrer accumulates
/// 5 referred users who have each made at least one paid upgrade.
class ReferralService {
  static final ReferralService instance = ReferralService._internal();
  ReferralService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int referralsNeededForReward = 5;
  static const int rewardDays = 30;

  CollectionReference get _usersCollection => _firestore.collection('users');

  String _generateCandidateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // avoids ambiguous chars like 0/O, 1/I
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Returns this user's referral code, generating and saving a unique one
  /// if they don't have one yet.
  Future<String> getOrCreateReferralCode(String uid) async {
    final userDoc = await _usersCollection.doc(uid).get();
    final data = userDoc.data() as Map<String, dynamic>?;

    if (data != null &&
        data['referralCode'] != null &&
        (data['referralCode'] as String).isNotEmpty) {
      return data['referralCode'] as String;
    }

    String code = _generateCandidateCode();
    for (int attempt = 0; attempt < 5; attempt++) {
      final existing = await _usersCollection
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) break;
      code = _generateCandidateCode();
    }

    await _usersCollection.doc(uid).set({
      'referralCode': code,
    }, SetOptions(merge: true));

    return code;
  }

  /// Called once, the first time a user signs in, with whatever referral
  /// code they entered (or null if none/skip). Links them to their
  /// referrer if the code is valid and they aren't already linked.
  Future<void> recordReferralIfNew(String newUserUid, String? enteredCode) async {
    if (enteredCode == null || enteredCode.trim().isEmpty) return;
    final code = enteredCode.trim().toUpperCase();

    final newUserDoc = await _usersCollection.doc(newUserUid).get();
    final existingData = newUserDoc.data() as Map<String, dynamic>?;
    if (existingData != null && existingData['referredBy'] != null) {
      return; // Already linked, never overwrite
    }

    final matches = await _usersCollection
        .where('referralCode', isEqualTo: code)
        .limit(1)
        .get();
    if (matches.docs.isEmpty) return; // Invalid code, silently ignore

    final referrerUid = matches.docs.first.id;
    if (referrerUid == newUserUid) return; // Can't refer yourself

    await _usersCollection.doc(newUserUid).set({
      'referredBy': referrerUid,
      'referralCreditGiven': false,
    }, SetOptions(merge: true));
  }

  /// Call this whenever a user's subscription becomes active (paid).
  /// Idempotent — only actually grants credit once per referred user,
  /// via the referralCreditGiven flag, so it's safe to call repeatedly.
  Future<void> onUserUpgraded(String uid) async {
    final userDoc = await _usersCollection.doc(uid).get();
    final data = userDoc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final referrerUid = data['referredBy'] as String?;
    final alreadyCredited = data['referralCreditGiven'] == true;

    if (referrerUid == null || alreadyCredited) return;

    // Mark this referred user as credited first, to avoid double-counting
    // if this fires more than once in quick succession.
    await _usersCollection.doc(uid).set({
      'referralCreditGiven': true,
    }, SetOptions(merge: true));

    final referrerDocRef = _usersCollection.doc(referrerUid);
    final referrerDoc = await referrerDocRef.get();
    final referrerData = referrerDoc.data() as Map<String, dynamic>?;
    final currentCount = (referrerData?['referralQualifiedCount'] ?? 0) as int;
    final newCount = currentCount + 1;

    await referrerDocRef.set({
      'referralQualifiedCount': newCount,
    }, SetOptions(merge: true));

    // Grant a reward every time the count crosses a new multiple of 5
    if (newCount % referralsNeededForReward == 0) {
      await _grantFreeMonth(referrerUid);
    }
  }

  Future<void> _grantFreeMonth(String referrerUid) async {
    final subRef = _firestore
        .collection('users')
        .doc(referrerUid)
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

    final newExpiry = baseDate.add(const Duration(days: rewardDays));

    await subRef.set({
      'isSubscribed': true,
      'expiryDate': Timestamp.fromDate(newExpiry),
      'lastReferralRewardAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns {code, qualifiedCount} for displaying on the Dashboard.
  Future<Map<String, dynamic>> getReferralStats(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    final data = doc.data() as Map<String, dynamic>?;
    return {
      'code': data?['referralCode'] ?? '',
      'qualifiedCount': (data?['referralQualifiedCount'] ?? 0) as int,
    };
  }
}
