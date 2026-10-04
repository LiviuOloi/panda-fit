import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';

class AuthRepository {
  final SupabaseClient? _client;

  AuthRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  User? get currentUser => _client?.auth.currentUser;
  Session? get currentSession => _client?.auth.currentSession;
  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  Future<AuthResponse?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (_client == null) return null;
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_client == null) return null;
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}
