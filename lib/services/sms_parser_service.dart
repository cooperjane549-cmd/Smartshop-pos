import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sale_transaction.dart';
import 'local_db_service.dart';

class ParsedMpesaPayment {
  final String code;
  final double amount;
  final String senderPhone;

  ParsedMpesaPayment({
    required this.code,
    required this.amount,
    required this.senderPhone,
  });
}

class SmsParserService {
  final Telephony telephony = Telephony.instance;
  static const String appTillNumber = "3043489";
  static const String trialKey = "app_install_date";

  /// Checks if the app is currently within the 10-day free trial period.
  Future<bool> isTrialActive() async {
    final prefs = await SharedPreferences.getInstance();
    int? installTimestamp = prefs.getInt(trialKey);

    if (installTimestamp == null) {
      installTimestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(trialKey, installTimestamp);
      return true;
    }

    final installDate = DateTime.fromMillisecondsSinceEpoch(installTimestamp);
    final daysUsed = DateTime.now().difference(installDate).inDays;
    return daysUsed < 10;
  }

  Future<bool> requestSmsPermissions() async {
    PermissionStatus status = await Permission.sms.request();
    return status.isGranted;
  }

  void startListening({
    required String storeTillNumber,
    required List<SaleTransaction> currentSales,
    required Function(ParsedMpesaPayment) onPaymentDetected,
    required Function(String saleId, String mpesaCode) onDebtAutoCleared,
    required Function(bool isSubscribed, DateTime expiryDate) onSubscriptionUpdated,
  }) {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        String body = message.body ?? '';
        String sender = message.address ?? '';

        if (sender.toUpperCase().contains('MPESA') ||
            body.contains('Confirmed.')) {
          ParsedMpesaPayment? payment = parseSms(body);
          if (payment != null) {
            onPaymentDetected(payment);

            // 1. Process App Subscription Verification (Till 3043489)
            if (body.contains(appTillNumber)) {
              if (payment.amount >= 1100) {
                DateTime expiry = DateTime.now().add(const Duration(days: 365));
                onSubscriptionUpdated(true, expiry);
              } else if (payment.amount >= 100) {
                DateTime expiry = DateTime.now().add(const Duration(days: 30));
                onSubscriptionUpdated(true, expiry);
              }
              return;
            }

            // 2. Process Store Debt Clearance
            if (storeTillNumber.isNotEmpty && body.contains(storeTillNumber)) {
              final unpaidSales = currentSales.where((s) =>
                  s.paymentMethod == 'CREDIT' &&
                  !s.isPaid &&
                  (s.totalAmount - payment.amount).abs() < 1.0).toList();

              if (unpaidSales.isNotEmpty) {
                final saleToClear = unpaidSales.first;
                LocalDbService.instance.markSalePaid(saleToClear.id, payment.code);
                onDebtAutoCleared(saleToClear.id, payment.code);
              }
            }
          }
        }
      },
      listenInBackground: false,
    );
  }

  ParsedMpesaPayment? parseSms(String body) {
    try {
      RegExp codeRegex = RegExp(r'^([A-Z0-9]+)\sConfirmed');
      RegExp amountRegex = RegExp(r'(?:Ksh|KES)\s*([\d,]+\.?\d*)');
      RegExp phoneRegex = RegExp(r'(\b254\d{9}\b|\b07\d{8}\b|\b01\d{8}\b)');

      var codeMatch = codeRegex.firstMatch(body);
      var amountMatch = amountRegex.firstMatch(body);
      var phoneMatch = phoneRegex.firstMatch(body);

      if (codeMatch != null && amountMatch != null) {
        String code = codeMatch.group(1)!;
        String rawAmount = amountMatch.group(1)!.replaceAll(',', '');
        double amount = double.parse(rawAmount);
        String phone = phoneMatch != null ? phoneMatch.group(0)! : '';

        return ParsedMpesaPayment(
          code: code,
          amount: amount,
          senderPhone: phone,
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
