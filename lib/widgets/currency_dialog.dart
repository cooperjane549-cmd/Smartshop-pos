import 'package:flutter/material.dart';
import '../services/currency_service.dart';

/// Shows a simple list of supported currencies; returns true if the user
/// picked a new one (caller should setState/rebuild after this returns).
class CurrencyDialog {
  static Future<bool> show(BuildContext context, String uid) async {
    String selected = CurrencyService.code;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Choose Currency'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: CurrencyService.supportedCurrencies.entries.map((entry) {
                    final code = entry.key;
                    final label = entry.value['label']!;
                    return RadioListTile<String>(
                      value: code,
                      groupValue: selected,
                      title: Text(label),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selected = val);
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () async {
                    await CurrencyService.instance.setCurrency(uid, selected);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }
}
