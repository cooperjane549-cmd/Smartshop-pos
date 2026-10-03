import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/referral_service.dart';
import '../views/login_view.dart';
import '../main.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF4F6F8),
            body: Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return _PostAuthInitializer(user: snapshot.data!);
        }

        return const LoginView();
      },
    );
  }
}

/// Runs once right after a successful sign-in: ensures the user's top-level
/// Firestore profile doc exists (and has a referral code), and if this is a
/// brand-new user, prompts them once for an optional referral code before
/// entering the app.
///
/// Wrapped defensively: any error here is caught and logged rather than
/// left to silently hang the app on the loading spinner, and a hard
/// timeout guarantees the app always proceeds within a few seconds even if
/// Firestore is unreachable or a permission rule blocks something.
class _PostAuthInitializer extends StatefulWidget {
  final User user;
  const _PostAuthInitializer({required this.user});

  @override
  State<_PostAuthInitializer> createState() => _PostAuthInitializerState();
}

class _PostAuthInitializerState extends State<_PostAuthInitializer> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _doInitialize().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('AuthGate initialization error (proceeding anyway): $e');
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  Future<void> _doInitialize() async {
    final firestore = FirebaseFirestore.instance;
    final userDocRef = firestore.collection('users').doc(widget.user.uid);
    final existingDoc = await userDocRef.get();
    final isBrandNewUser = !existingDoc.exists;

    if (isBrandNewUser) {
      await userDocRef.set({
        'email': widget.user.email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Every user (new or returning) should have a referral code.
    await ReferralService.instance.getOrCreateReferralCode(widget.user.uid);

    if (isBrandNewUser && mounted) {
      await _showReferralCodePrompt();
    }
  }

  Future<void> _showReferralCodePrompt() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Welcome to SmartShop POS!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Were you referred by someone? Enter their code below (optional).'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Referral Code (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () async {
              try {
                await ReferralService.instance.recordReferralIfNew(
                  widget.user.uid,
                  controller.text.trim().isEmpty ? null : controller.text.trim(),
                );
              } catch (e) {
                debugPrint('Referral recording error (ignored): $e');
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F8),
        body: Center(
          child: CircularProgressIndicator(color: Colors.indigo),
        ),
      );
    }
    return const MainNavigationHub();
  }
}
