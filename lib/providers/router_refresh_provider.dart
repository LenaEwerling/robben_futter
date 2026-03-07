import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_providers.dart';

class AuthRouterRefreshNotifier extends ChangeNotifier {
  AuthRouterRefreshNotifier(this.ref) {
    // Listener registrieren – Rückgabewert ignorieren (Riverpod managed das Cleanup)
    ref.listen<AsyncValue<User?>>(
      authNotifierProvider,
          (previous, next) {
        // Trigger GoRouter-Refresh bei JEDER Änderung (loading → data, error, etc.)
        notifyListeners();
      },
    );
  }

  final Ref ref;

  // Kein explizites dispose() nötig, da ref.listen automatisch cleaned wird,
  // wenn routerRefreshProvider disposed wird (was bei App-Lifecycle passiert)
  // Optional: Falls du etwas extra cleanen willst:
  @override
  void dispose() {
    super.dispose();
    // Hier ggf. weitere Cleanup, aber meist unnötig
  }
}

final routerRefreshProvider = Provider<AuthRouterRefreshNotifier>(
      (ref) => AuthRouterRefreshNotifier(ref),
  // keepAlive: true,   // ← optional, wenn du den Listener app-weit behalten willst
);