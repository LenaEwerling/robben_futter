import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart'; // ← hier kommt der globale supabase-Client her

// ────────────────────────────────────────────────
// AuthService (nur noch Wrapper – kein Init mehr)
class AuthService {
  User? get currentUser => supabase.auth.currentUser;

  Stream<User?> get authStateChanges => supabase.auth.onAuthStateChange.map((data) => data.session?.user);

  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ────────────────────────────────────────────────
// Zentraler Auth-Notifier
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // Initial: aktuellen User prüfen (Session prüfen)
    return ref.read(authServiceProvider).currentUser;
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();

    try {
      await ref.read(authServiceProvider).signIn(email, password);
      final currentUser = ref.read(authServiceProvider).currentUser;

      if (currentUser == null) {
        throw Exception('Login erfolgreich, aber currentUser ist null');
      }

      state = AsyncData(currentUser);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await ref.read(authServiceProvider).signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ────────────────────────────────────────────────
// userRoleProvider – Stream bleibt
final userRoleProvider = StreamProvider.autoDispose<String?>((ref) async* {
  await for (final user in ref.watch(authServiceProvider).authStateChanges) {
    if (user == null) {
      yield null;
      continue;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      yield response?['role'] as String?;
    } catch (_) {
      yield null;
    }
  }
});

final isAdminProvider = Provider<bool>((ref) {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.valueOrNull == 'admin';
});