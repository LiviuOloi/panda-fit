import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(SupabaseService.client);
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges ?? const Stream.empty();
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  if (authState != null) {
    return authState.session?.user;
  }
  return ref.watch(authRepositoryProvider).currentUser;
});

class AuthStateData {
  final bool isLoading;
  final String? errorMessage;

  const AuthStateData({this.isLoading = false, this.errorMessage});
}

class AuthController extends StateNotifier<AuthStateData> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AuthStateData());

  Future<bool> signIn({required String email, required String password}) async {
    state = const AuthStateData(isLoading: true);
    try {
      final res = await _repo.signInWithEmail(email: email.trim(), password: password);
      if (res?.session != null || res?.user != null) {
        state = const AuthStateData(isLoading: false);
        return true;
      } else {
        state = const AuthStateData(isLoading: false, errorMessage: 'Authentication failed. Please check credentials.');
        return false;
      }
    } on AuthException catch (e) {
      state = AuthStateData(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = AuthStateData(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> signUp({required String email, required String password}) async {
    state = const AuthStateData(isLoading: true);
    try {
      final res = await _repo.signUpWithEmail(email: email.trim(), password: password);
      if (res?.user != null) {
        state = const AuthStateData(isLoading: false);
        return true;
      } else {
        state = const AuthStateData(isLoading: false, errorMessage: 'Sign up failed.');
        return false;
      }
    } on AuthException catch (e) {
      state = AuthStateData(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = AuthStateData(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AuthStateData(isLoading: true);
    await _repo.signOut();
    state = const AuthStateData(isLoading: false);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthStateData>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});
