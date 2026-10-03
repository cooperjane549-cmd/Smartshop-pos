import 'package:flutter/material.dart';
import '../services/pin_service.dart';

/// Reusable PIN dialogs: first-time setup, verification gate, and
/// forgot-PIN reset via re-authentication.
class PinDialog {
  /// Shows the first-time "create your PIN" dialog. Returns true if a PIN
  /// was successfully created, false if the user cancelled.
  static Future<bool> showSetup(BuildContext context) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set Up Security PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create an 8-character PIN (mix of letters and numbers). '
                    'You\'ll need this to edit stock, delete products, or delete recent sales.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'New PIN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 6),
                    Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final confirm = confirmController.text.trim();

                    final formatError = PinService.instance.validatePinFormat(pin);
                    if (formatError != null) {
                      setDialogState(() => errorText = formatError);
                      return;
                    }
                    if (pin != confirm) {
                      setDialogState(() => errorText = 'PINs do not match.');
                      return;
                    }

                    await PinService.instance.setPin(pin);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Set PIN', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }

  /// Shows the "enter PIN to proceed" gate. Returns true if the correct PIN
  /// was entered, false if cancelled or still locked out. If no PIN has
  /// been set yet at all, this instead forces setup first.
  static Future<bool> verify(BuildContext context, {String reason = 'Enter your security PIN to continue'}) async {
    final hasPin = await PinService.instance.hasPinSet();
    if (!hasPin) {
      return showSetup(context);
    }

    final pinController = TextEditingController();
    String? statusText;
    bool locked = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reason),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    maxLength: 8,
                    enabled: !locked,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (statusText != null) ...[
                    const SizedBox(height: 6),
                    Text(statusText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx, false);
                        await _handleForgotPin(context);
                      },
                      child: const Text('Forgot PIN?'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: locked
                      ? null
                      : () async {
                          final entered = pinController.text.trim();
                          final check = await PinService.instance.verifyPin(entered);
                          if (check.success) {
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } else {
                            setDialogState(() {
                              statusText = check.message;
                              locked = check.locked;
                            });
                          }
                        },
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }

  static Future<void> _handleForgotPin(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset PIN'),
        content: const Text(
          'To reset your PIN, we\'ll confirm it\'s really you by re-checking your Google sign-in. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final verified = await PinService.instance.reauthenticateForPinReset();
    if (!context.mounted) return;

    if (!verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not verify your identity. Please sign in again and retry.')),
      );
      return;
    }

    await showSetup(context);
  }
}
