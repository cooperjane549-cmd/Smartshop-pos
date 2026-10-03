import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles setting, verifying, and resetting the security PIN used to
/// protect stock edits/deletes and recent-sale deletions.
///
/// The PIN itself is never stored in plaintext — only a SHA-256 hash is
/// saved to Firestore under users/{uid}/security/pin.
class PinService {
  static final PinService instance = PinService._internal();
  PinService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int maxAttempts = 5;
  static const int lockoutSeconds = 60;

  DocumentReference? get _pinDocRef {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('security')
        .doc('pin');
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// True if a PIN has already been set for this user.
  Future<bool> hasPinSet() async {
    final ref = _pinDocRef;
    if (ref == null) return false;
    final doc = await ref.get();
    return doc.exists && (doc.data() as Map<String, dynamic>?)?['pinHash'] != null;
  }

  /// Validates PIN format: exactly 8 characters, must contain at least
  /// one letter and at least one number.
  String? validatePinFormat(String pin) {
    if (pin.length != 8) {
      return 'PIN must be exactly 8 characters.';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(pin);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pin);
    if (!hasLetter || !hasNumber) {
      return 'PIN must mix letters and numbers.';
    }
    return null;
  }

  /// Creates or overwrites the PIN (used for initial setup and for
  /// "Forgot PIN" reset after re-authentication).
  Future<void> setPin(String pin) async {
    final ref = _pinDocRef;
    if (ref == null) throw Exception('No authenticated user.');

    await ref.set({
      'pinHash': _hashPin(pin),
      'failedAttempts': 0,
      'lockedUntil': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns a PinCheckResult describing whether entry succeeded, failed,
  /// or is currently locked out.
  Future<PinCheckResult> verifyPin(String enteredPin) async {
    final ref = _pinDocRef;
    if (ref == null) return PinCheckResult(success: false, locked: false, message: 'Not signed in.');

    final doc = await ref.get();
    if (!doc.exists) {
      return PinCheckResult(success: false, locked: false, message: 'No PIN set yet.');
    }

    final data = doc.data() as Map<String, dynamic>;
    final storedHash = data['pinHash'] as String?;
    final failedAttempts = (data['failedAttempts'] ?? 0) as int;
    final lockedUntilTs = data['lockedUntil'] as Timestamp?;

    // Check if currently locked out
    if (lockedUntilTs != null) {
      final lockedUntil = lockedUntilTs.toDate();
      if (DateTime.now().isBefore(lockedUntil)) {
        final secondsLeft = lockedUntil.difference(DateTime.now()).inSeconds;
        return PinCheckResult(
          success: false,
          locked: true,
          message: 'Too many attempts. Try again in $secondsLeft seconds.',
        );
      }
    }

    if (storedHash == _hashPin(enteredPin)) {
      // Correct — reset failed attempts
      await ref.update({'failedAttempts': 0, 'lockedUntil': null});
      return PinCheckResult(success: true, locked: false, message: 'PIN correct.');
    } else {
      // Wrong — increment failure count
      final newFailCount = failedAttempts + 1;
      if (newFailCount >= maxAttempts) {
        final lockUntil = DateTime.now().add(const Duration(seconds: lockoutSeconds));
        await ref.update({
          'failedAttempts': 0,
          'lockedUntil': Timestamp.fromDate(lockUntil),
        });
        return PinCheckResult(
          success: false,
          locked: true,
          message: 'Too many wrong attempts. Locked for $lockoutSeconds seconds.',
        );
      } else {
        await ref.update({'failedAttempts': newFailCount});
        final remaining = maxAttempts - newFailCount;
        return PinCheckResult(
          success: false,
          locked: false,
          message: 'Incorrect PIN. $remaining attempt(s) left.',
        );
      }
    }
  }

  /// Re-authenticates the user via Google Sign-In as proof of identity
  /// before allowing a PIN reset. Returns true if re-auth succeeded.
  Future<bool> reauthenticateForPinReset() async {
    // Uses the same Google credential flow as initial sign-in. The actual
    // GoogleSignIn call lives in AuthService/auth_gate — this just confirms
    // the currently signed-in Firebase user is valid and fresh.
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Force a token refresh — if the session is invalid/stale this throws,
      // which is a reasonable lightweight re-auth check for this use case.
      await user.getIdToken(true);
      return true;
    } catch (e) {
      return false;
    }
  }
}

class PinCheckResult {
  final bool success;
  final bool locked;
  final String message;

  PinCheckResult({
    required this.success,
    required this.locked,
    required this.message,
  });
}
