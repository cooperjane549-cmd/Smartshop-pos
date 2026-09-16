import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

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

  Future<bool> requestSmsPermissions() async {
    PermissionStatus status = await Permission.sms.request();
    return status.isGranted;
  }

  void startListening(Function(ParsedMpesaPayment) onPaymentDetected) {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        String body = message.body ?? '';
        String sender = message.address ?? '';

        if (sender.toUpperCase().contains('MPESA') ||
            body.contains('Confirmed.')) {
          ParsedMpesaPayment? payment = parseSms(body);
          if (payment != null) {
            onPaymentDetected(payment);
          }
        }
      },
      listenInBackground: false,
    );
  }

  ParsedMpesaPayment? parseSms(String body) {
    try {
      RegExp codeRegex = RegExp(r'^([A-Z0-9]+)\sConfirmed');
      RegExp amountRegex = RegExp(r'Ksh([\d,]+\.\d{2})');
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
