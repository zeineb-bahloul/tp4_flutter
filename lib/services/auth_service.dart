import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentification email / mot de passe via Supabase Auth.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Retourne true si l'utilisateur est connecté directement,
  /// false s'il doit d'abord confirmer son email.
  Future<bool> signUp(String email, String password) async {
    final res = await _client.auth.signUp(email: email, password: password);
    return res.session != null;
  }

  Future<void> signOut() => _client.auth.signOut();
}

/// Traduit les erreurs Supabase en messages lisibles.
String authErrorMessage(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Email ou mot de passe incorrect.';
    if (m.contains('email not confirmed')) {
      return 'Confirmez d\'abord votre email (vérifiez votre boîte de réception).';
    }
    if (m.contains('already registered')) return 'Cet email a déjà un compte.';
    if (m.contains('rate limit')) {
      return 'Trop de tentatives, réessayez dans quelques minutes.';
    }
    return e.message;
  }
  return 'Erreur : $e';
}
