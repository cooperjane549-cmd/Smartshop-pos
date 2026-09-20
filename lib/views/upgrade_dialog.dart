import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class UpgradeDialog extends StatefulWidget {
  const UpgradeDialog({Key? key}) : super(key: key);

  @override
  _UpgradeDialogState createState() => _UpgradeDialogState();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const UpgradeDialog(),
    );
  }
}

class _UpgradeDialogState extends State<UpgradeDialog> {
  final TextEditingController _mpesaController = TextEditingController();
  bool _isLoading = false;
  String _selectedPlan = '30 Days (KES 100)';

  Future<void> _submitUpgrade() async {
    final message = _mpesaController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste your M-Pesa payment message or transaction code.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'UNKNOWN_USER';
    final userEmail = user?.email ?? 'No email';
    final userName = user?.displayName ?? 'Shop Owner';

    try {
      final response = await http.post(
        Uri.parse('https://smartshop-pos-render.onrender.com/send-upgrade-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'userEmail': userEmail,
          'userName': userName,
          'mpesaMessage': message,
          'planName': _selectedPlan,
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text('Upgrade request sent! Your subscription will unlock once verified.'),
            ),
          );
        }
      } else {
        throw Exception('Server responded with status code ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to submit request: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upgrade SmartShop POS'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send payment to Till Number 3043489, then paste the M-Pesa SMS confirmation below.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedPlan,
              decoration: const InputDecoration(
                labelText: 'Select Subscription Plan',
                border: OutlineInputBorder(),
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
                if (val != null) setState(() => _selectedPlan = val);
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _mpesaController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Paste M-Pesa Message / Code',
                hintText: 'e.g. QGH89XX12 Confirmed. Ksh100 sent to...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          onPressed: _isLoading ? null : _submitUpgrade,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Submit Payment', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
