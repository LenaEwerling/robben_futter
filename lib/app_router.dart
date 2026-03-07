import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/router_refresh_provider.dart';
import '../screens/login_screen.dart';
import '../screens/start_screen.dart';
import '../screens/test_dishes_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    refreshListenable: ref.watch(routerRefreshProvider),

    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);

      final currentPath = state.uri.path;

      // Während Loading → kein Redirect (verhindert Loop während signIn)
      if (authState.isLoading) {
        return null;
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null && user.id.isNotEmpty; // extra sicher

      print('Redirect check: path=$currentPath, isLoggedIn=$isLoggedIn, user=${user?.email}');

      // Nicht eingeloggt und nicht schon auf login → zu login
      if (!isLoggedIn && currentPath != '/login') {
        print('→ Redirect to /login (not logged in)');
        return '/login';
      }

      // Eingeloggt und auf login → zu home
      if (isLoggedIn && currentPath == '/login') {
        print('→ Redirect to / (logged in)');
        return '/';
      }

      // Alles andere: kein Redirect
      return null;
    },

    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ShellWithBottomNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const StartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dishes',
                name: 'dishes',
                builder: (context, state) => TestDishesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _ShellWithBottomNav extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const _ShellWithBottomNav({required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RobbenFutter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Ausloggen',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              // redirect triggert automatisch → kein manuelles pushReplacement nötig
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Erfolgreich ausgeloggt')),
              );
            },
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Gerichte'),
        ],
      ),
    );
  }
}