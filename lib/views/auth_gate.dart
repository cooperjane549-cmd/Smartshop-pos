import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
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
        // Connection state loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF4F6F8),
            body: Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            ),
          );
        }

        // Authenticated -> proceed to app dashboard hub
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavigationHub();
        }

        // Not authenticated -> show Google Sign-In
        return const LoginView();
      },
    );
  }
}
