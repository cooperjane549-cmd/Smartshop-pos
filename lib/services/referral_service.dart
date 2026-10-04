import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralService {
  static final ReferralService instance = ReferralService._internal();
  ReferralService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int referralsNeededForReward = 5;
  static const int rewardDays = 30;

  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _codesCollection => _firestore.collection('referral_codes');

  String _generateCandidateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

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
      final existing = await _codesCollection.doc(code).get();
      if (!existing.exists) break;
      code = _generateCandidateCode();
    }

    await _codesCollection.doc(code).set({'uid': uid});
    await _usersCollection.doc(uid).set({
      'referralCode': code,
    }, SetOptions(merge: true));

    return code;
  }

  Future<void> recordReferralIfNew(String newUserUid, String? enteredCode) async {
    if (enteredCode == null || enteredCode.trim().isEmpty) return;
    final code = enteredCode.trim().toUpperCase();

    final newUserDoc = await _usersCollection.doc(newUserUid).get();
    final existingData = newUserDoc.data() as Map<String, dynamic>?;
    if (existingData != null && existingData['referredBy'] != null) {
      return;
    }

    final codeDoc = await _codesCollection.doc(code).get();
    if (!codeDoc.exists) return;

    final codeData = codeDoc.data() as Map<String, dynamic>?;
    final referrerUid = codeData?['uid'] as String?;
    if (referrerUid == null || referrerUid == newUserUid) return;

    await _usersCollection.doc(newUserUid).set({
      'referredBy': referrerUid,
      'referralCreditGiven': false,
    }, SetOptions(merge: true));
  }

  Future<void> onUserUpgraded(String uid) async {
    final userDoc = await _usersCollection.doc(uid).get();
    final data = userDoc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final referrerUid = data['referredBy'] as String?;
    final alreadyCredited = data['referralCreditGiven'] == true;

    if (referrerUid == null || alreadyCredited) return;

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

  Future<Map<String, dynamic>> getReferralStats(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    final data = doc.data() as Map<String, dynamic>?;
    return {
      'code': data?['referralCode'] ?? '',
      'qualifiedCount': (data?['referralQualifiedCount'] ?? 0) as int,
    };
  }
}
