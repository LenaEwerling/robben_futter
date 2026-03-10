import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robben_futter/screens/dish_detail_screen.dart';
import 'package:robben_futter/screens/dishes_list.dart';

import '../providers/auth_providers.dart';
import '../providers/router_refresh_provider.dart';
import '../screens/login_screen.dart';
import '../screens/start_screen.dart';
import '../screens/dish_detail_screen.dart';
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
                name: 'dishes-list',
                builder: (context, state) => DishesListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'dish-detail',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return DishDetailScreen(dishId: id);
                    },
                  ),
                ],
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100), // ← Gesamthöhe der AppBar erhöhen (80–120 px)
        child: AppBar(
          toolbarHeight: 100, // ← Höhe der Toolbar selbst
          title: SvgPicture.asset(
            'assets/Logo.svg',
            height: 80, // dein gewünschtes Logo-Höhe
            fit: BoxFit.contain,
          ),
          centerTitle: true,
          titleSpacing: 0, // entfernt unnötigen Abstand links
          elevation: 0, // optional: flacher Look
          backgroundColor: Colors.white, // oder dein Theme-Farbe
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Ausloggen',
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erfolgreich ausgeloggt')),
                );
              },
            ),
          ],
        ),
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