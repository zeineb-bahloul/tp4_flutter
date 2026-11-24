import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/login_screen.dart';
import '../screens/queue_screen.dart';
import '../services/auth_service.dart';

/// Affiche LoginScreen si l'utilisateur n'est pas connecté,
/// sinon QueueScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.supabaseReady});

  /// false si Supabase n'a pas pu être initialisé.
  final bool supabaseReady;

  @override
  Widget build(BuildContext context) {
    if (!supabaseReady) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Supabase n\'est pas disponible : connexion impossible.\n'
              'Vérifiez le fichier .env et votre connexion internet.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final authService = AuthService();
    return StreamBuilder<AuthState>(
      stream: authService.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData
            ? snapshot.data!.session
            : authService.currentSession;
        return session != null ? const QueueScreen() : const LoginScreen();
      },
    );
  }
}
