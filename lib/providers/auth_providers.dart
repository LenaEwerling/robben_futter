import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

final authProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final supabase = Supabase.instance.client;

  User? get currentUser => supabase.auth.currentUser;

  Stream<User?> get authStateChanges => supabase.auth.onAuthStateChange.map((data) => data.session?.user);

  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    // Nur signOut – recoverSession ist in den meisten Fällen nicht nötig
    await supabase.auth.signOut();
  }
}

// ────────────────────────────────────────────────
//          ←  Die wichtigste Verbesserung  →
final userRoleProvider = StreamProvider.autoDispose<String?>((ref) async* {
  // Wir hören auf jeden Auth-State-Change
  await for (final user in ref.watch(authProvider).authStateChanges) {
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

      final role = response?['role'] as String?;
      yield role;
    } catch (e) {
      // Im Fehlerfall → null oder Fehler behandeln
      // Hier einfach null → du kannst auch einen separaten Error-State machen
      yield null;
    }
  }
});

final isAdminProvider = Provider<bool>((ref) {
  final roleAsync = ref.watch(userRoleProvider);
  // .valueOrNull ist sicherer als .value (vermeidet StateError bei loading/error)
  return roleAsync.valueOrNull == 'admin';
});