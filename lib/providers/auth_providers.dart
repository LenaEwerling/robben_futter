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
    await supabase.auth.signOut();
  }
}

final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) return null;

  final response = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();

  return response?['role'] as String?;
});

final isAdminProvider = Provider<bool>((ref) {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.value == 'admin';
});
