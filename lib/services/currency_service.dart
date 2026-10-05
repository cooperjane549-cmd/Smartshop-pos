import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Detects a sensible default currency from the device locale, lets the
/// user override it, and persists the choice. Exposes the current symbol
/// as an in-memory cache (CurrencyService.symbol) so widgets can read it
/// synchronously without a StreamBuilder on every screen. The cache is
/// refreshed once at startup and whenever the user changes it.
class CurrencyService {
  static final CurrencyService instance = CurrencyService._internal();
  CurrencyService._internal();

  // In-memory cache — read this directly from any widget for the symbol.
  static String code = 'KES';
  static String symbol = 'KES';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // A practical subset of common currencies. Extend anytime.
  static const Map<String, Map<String, String>> supportedCurrencies = {
    'KES': {'symbol': 'KES', 'label': 'Kenyan Shilling (KES)'},
    'USD': {'symbol': '\$', 'label': 'US Dollar (USD)'},
    'EUR': {'symbol': '€', 'label': 'Euro (EUR)'},
    'GBP': {'symbol': '£', 'label': 'British Pound (GBP)'},
    'NGN': {'symbol': '₦', 'label': 'Nigerian Naira (NGN)'},
    'GHS': {'symbol': 'GH₵', 'label': 'Ghanaian Cedi (GHS)'},
    'ZAR': {'symbol': 'R', 'label': 'South African Rand (ZAR)'},
    'UGX': {'symbol': 'USh', 'label': 'Ugandan Shilling (UGX)'},
    'TZS': {'symbol': 'TSh', 'label': 'Tanzanian Shilling (TZS)'},
    'INR': {'symbol': '₹', 'label': 'Indian Rupee (INR)'},
    'PKR': {'symbol': '₨', 'label': 'Pakistani Rupee (PKR)'},
    'CAD': {'symbol': 'CA\$', 'label': 'Canadian Dollar (CAD)'},
    'AUD': {'symbol': 'A\$', 'label': 'Australian Dollar (AUD)'},
  };

  // Rough country-code -> currency-code map for auto-detection.
  static const Map<String, String> _countryToCurrency = {
    'KE': 'KES', 'US': 'USD', 'GB': 'GBP', 'NG': 'NGN', 'GH': 'GHS',
    'ZA': 'ZAR', 'UG': 'UGX', 'TZ': 'TZS', 'IN': 'INR', 'PK': 'PKR',
    'CA': 'CAD', 'AU': 'AUD',
  };

  String _detectFromLocale() {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode ?? 'KE';
      return _countryToCurrency[countryCode] ?? 'KES';
    } catch (_) {
      return 'KES';
    }
  }

  /// Call once at startup (after sign-in). Loads the user's saved currency
  /// if present; otherwise detects from locale and saves that as default.
  Future<void> initialize(String uid) async {
    final userDocRef = _firestore.collection('users').doc(uid);
    final doc = await userDocRef.get();
    final data = doc.data() as Map<String, dynamic>?;

    final savedCode = data?['currencyCode'] as String?;
    if (savedCode != null && supportedCurrencies.containsKey(savedCode)) {
      code = savedCode;
      symbol = supportedCurrencies[savedCode]!['symbol']!;
      return;
    }

    final detected = _detectFromLocale();
    code = detected;
    symbol = supportedCurrencies[detected]!['symbol']!;

    await userDocRef.set({
      'currencyCode': code,
    }, SetOptions(merge: true));
  }

  /// Called when the user manually changes their currency from the
  /// Dashboard. Updates both the cache and Firestore.
  Future<void> setCurrency(String uid, String newCode) async {
    if (!supportedCurrencies.containsKey(newCode)) return;
    code = newCode;
    symbol = supportedCurrencies[newCode]!['symbol']!;

    await _firestore.collection('users').doc(uid).set({
      'currencyCode': code,
    }, SetOptions(merge: true));
  }
}
