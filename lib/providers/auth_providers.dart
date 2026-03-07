import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// ────────────────────────────────────────────────
// AuthService bleibt fast gleich (nur als Client-Hilfe)
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
// Zentraler Auth-Notifier (AsyncNotifier → loading/error/data)
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<User?> {
  // Kein Konstruktor nötig – ref ist automatisch verfügbar!

  @override
  Future<User?> build() async {
    // Initial: aktuellen User prüfen (z. B. bei App-Start, wenn Session noch gültig)
    return ref.read(authServiceProvider).currentUser;
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();

    try {
      // Supabase-Login ausführen
      await ref.read(authServiceProvider).signIn(email, password);

      // WICHTIG: User NACH dem Login abrufen – Session wird asynchron aktualisiert
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
// userRoleProvider bleibt StreamProvider.autoDispose (reagiert auf auth changes)
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