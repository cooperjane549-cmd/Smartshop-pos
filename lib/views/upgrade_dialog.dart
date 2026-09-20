import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpgradeDialog {
  static void show(BuildContext context) {
    final TextEditingController mpesaController = TextEditingController();
    final User? user = FirebaseAuth.instance.currentUser;
    String selectedPlan = '30 Days (KES 100)';
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Text('Upgrade SmartShop POS'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Select Plan:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedPlan,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '30 Days (KES 100)',
                          child: Text('30 Days - KES 100'),
                        ),
                        DropdownMenuItem(
                          value: '1 Year (KES 1100)',
                          child: Text('1 Year - KES 1,100'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedPlan = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '2. Pay via M-Pesa:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('• Go to M-Pesa -> Lipa na M-Pesa'),
                          Text('• Select Buy Goods and Services'),
                          Text(
                            '• Enter Till Number: 3043489',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          Text('• Enter Amount for selected plan'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '3. Paste M-Pesa Confirmation SMS:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: mpesaController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Paste full M-Pesa SMS message here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final text = mpesaController.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please paste your M-Pesa SMS message.'),
                              ),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            final response = await http.post(
                              Uri.parse('https://smartshop-pos-render.onrender.com/send-upgrade-request'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'uid': user?.uid ?? 'unknown_uid',
                                'userEmail': user?.email ?? 'no_email',
                                'userName': user?.displayName ?? 'Merchant',
                                'mpesaMessage': text,
                                'planName': selectedPlan,
                              }),
                            );

                            if (response.statusCode == 200) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text(
                                    'Upgrade request submitted! You will be unlocked once approved.',
                                  ),
                                ),
                              );
                            } else {
                              throw Exception('Failed to send request');
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
                                content: Text('Error submitting request: $e'),
                              ),
                            );
                          } finally {
                            setState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
