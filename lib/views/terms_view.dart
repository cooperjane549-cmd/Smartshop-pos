import 'package:flutter/material.dart';

// ============================================================
// EDIT TERMS & CONDITIONS TEXT HERE — no need to touch any
// other code. Update kTermsLastUpdated too when you change this.
// ============================================================
const String kTermsLastUpdated = 'October 2026';
const String kTermsAndConditions = '''
SMARTSHOP POS — TERMS AND CONDITIONS

Last updated: October 2026

1. ACCEPTANCE OF TERMS
By downloading, installing, or using SmartShop POS ("the App"), you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the App.

2. DESCRIPTION OF SERVICE
SmartShop POS is a point-of-sale and inventory management application for small businesses, allowing users to track sales, manage stock, record customer credit (mkopo), and generate receipts.

3. ACCOUNT AND ELIGIBILITY
You must sign in using a valid Google account to use the App. You are responsible for maintaining the security of your account, including any PIN you set within the App for sensitive actions.

4. FREE TRIAL AND SUBSCRIPTIONS
New accounts receive a 10-day free trial. After the trial ends, continued use of certain features requires an active paid subscription (1, 3, 6, or 12 months), purchased through Google Play Billing. Subscription prices are displayed in-app at the time of purchase and may change; changes will not affect an already-active subscription period.

5. REFUNDS
Refunds for subscription payments are handled according to Google Play's refund policy. Contact us using the details provided in the App's Contact Us section if you experience a billing issue.

6. REFERRAL PROGRAM
Users may refer others using their unique referral code. A free 30-day extension is granted once 5 referred users have made at least one paid subscription payment. SmartShop reserves the right to adjust referral program terms at any time, with changes applying only to future referrals.

7. DATA AND PRIVACY
Your sales, inventory, and customer data are stored securely via Firebase (Google Cloud) under your own account and are not shared with other users or third parties, except as necessary to operate the App (e.g., Google Play Billing for payments). You are responsible for the accuracy of data you enter, including customer phone numbers used for credit tracking and WhatsApp reminders.

8. SECURITY PIN
The App allows you to set a PIN to protect sensitive actions (editing or deleting stock, deleting recent sales). You are responsible for remembering your PIN. A PIN reset requires re-verifying your identity through your Google account.

9. ACCEPTABLE USE
You agree not to use the App for any unlawful purpose, to misrepresent transaction data, or to attempt to interfere with the App's security features.

10. LIMITATION OF LIABILITY
SmartShop POS is provided "as is." We are not liable for lost data, lost sales, or business losses resulting from app downtime, user error, or third-party service outages (including Firebase, Google Play, or WhatsApp).

11. CHANGES TO THESE TERMS
We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the updated Terms.

12. CONTACT US
For questions, support, or billing issues, contact us via the details provided in the App's Contact Us section.
''';
// ============================================================

class TermsView extends StatelessWidget {
  const TermsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Last updated: $kTermsLastUpdated',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const Text(
              kTermsAndConditions,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
