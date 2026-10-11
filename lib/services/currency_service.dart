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

  // Comprehensive global currency dictionary.
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
    'JPY': {'symbol': '¥', 'label': 'Japanese Yen (JPY)'},
    'CNY': {'symbol': '¥', 'label': 'Chinese Yuan (CNY)'},
    'BRL': {'symbol': 'R\$', 'label': 'Brazilian Real (BRL)'},
    'MXN': {'symbol': 'MX\$', 'label': 'Mexican Peso (MXN)'},
    'AED': {'symbol': 'AED', 'label': 'UAE Dirham (AED)'},
    'SAR': {'symbol': 'SAR', 'label': 'Saudi Riyal (SAR)'},
    'CHF': {'symbol': 'CHF', 'label': 'Swiss Franc (CHF)'},
    'SEK': {'symbol': 'kr', 'label': 'Swedish Krona (SEK)'},
    'NOK': {'symbol': 'kr', 'label': 'Norwegian Krone (NOK)'},
    'DKK': {'symbol': 'kr', 'label': 'Danish Krone (DKK)'},
    'SGD': {'symbol': 'S\$', 'label': 'Singapore Dollar (SGD)'},
    'HKD': {'symbol': 'HK\$', 'label': 'Hong Kong Dollar (HKD)'},
    'NZD': {'symbol': 'NZ\$', 'label': 'New Zealand Dollar (NZD)'},
    'PLN': {'symbol': 'zł', 'label': 'Polish Złoty (PLN)'},
    'THB': {'symbol': '฿', 'label': 'Thai Baht (THB)'},
    'IDR': {'symbol': 'Rp', 'label': 'Indonesian Rupiah (IDR)'},
    'MYR': {'symbol': 'RM', 'label': 'Malaysian Ringgit (MYR)'},
    'PHP': {'symbol': '₱', 'label': 'Philippine Peso (PHP)'},
    'VND': {'symbol': '₫', 'label': 'Vietnamese Đồng (VND)'},
    'TRY': {'symbol': '₺', 'label': 'Turkish Lira (TRY)'},
    'EGP': {'symbol': 'E£', 'label': 'Egyptian Pound (EGP)'},
    'KRW': {'symbol': '₩', 'label': 'South Korean Won (KRW)'},
    'ARS': {'symbol': 'AR\$', 'label': 'Argentine Peso (ARS)'},
    'CLP': {'symbol': 'CL\$', 'label': 'Chilean Peso (CLP)'},
    'COP': {'symbol': 'CO\$', 'label': 'Colombian Peso (COP)'},
    'PEN': {'symbol': 'S/', 'label': 'Peruvian Sol (PEN)'},
    'CZK': {'symbol': 'Kč', 'label': 'Czech Koruna (CZK)'},
    'HUF': {'symbol': 'Ft', 'label': 'Hungarian Forint (HUF)'},
    'RON': {'symbol': 'lei', 'label': 'Romanian Leu (RON)'},
    'ILS': {'symbol': '₪', 'label': 'Israeli New Shekel (ILS)'},
    'BDT': {'symbol': '৳', 'label': 'Bangladeshi Taka (BDT)'},
    'LKR': {'symbol': 'Rs', 'label': 'Sri Lankan Rupee (LKR)'},
  };

  // Global country-code -> currency-code map for auto-detection.
  static const Map<String, String> _countryToCurrency = {
    'KE': 'KES', 'US': 'USD', 'GB': 'GBP', 'NG': 'NGN', 'GH': 'GHS',
    'ZA': 'ZAR', 'UG': 'UGX', 'TZ': 'TZS', 'IN': 'INR', 'PK': 'PKR',
    'CA': 'CAD', 'AU': 'AUD', 'JP': 'JPY', 'CN': 'CNY', 'BR': 'BRL',
    'MX': 'MXN', 'AE': 'AED', 'SA': 'SAR', 'CH': 'CHF', 'SE': 'SEK',
    'NO': 'NOK', 'DK': 'DKK', 'SG': 'SGD', 'HK': 'HKD', 'NZ': 'NZD',
    'PL': 'PLN', 'TH': 'THB', 'ID': 'IDR', 'MY': 'MYR', 'PH': 'PHP',
    'VN': 'VND', 'TR': 'TRY', 'EG': 'EGP', 'KR': 'KRW', 'AR': 'ARS',
    'CL': 'CLP', 'CO': 'COP', 'PE': 'PEN', 'CZ': 'CZK', 'HU': 'HUF',
    'RO': 'RON', 'IL': 'ILS', 'BD': 'BDT', 'LK': 'LKR',
    // Eurozone countries
    'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'ES': 'EUR', 'NL': 'EUR',
    'BE': 'EUR', 'AT': 'EUR', 'PT': 'EUR', 'FI': 'EUR', 'IE': 'EUR',
    'GR': 'EUR', 'SK': 'EUR', 'SI': 'EUR', 'CY': 'EUR', 'EE': 'EUR',
    'LV': 'EUR', 'LT': 'EUR', 'MT': 'EUR',
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
