import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robben_futter/providers/cart_provider.dart';

import '../providers/auth_providers.dart';
import '../providers/router_refresh_provider.dart';
import '../screens/login_screen.dart';
import '../screens/start_screen.dart';
import '../screens/dishes_list.dart';
import '../screens/dish_detail_screen.dart';
import '../screens/cart_screen.dart'; // ← dein Warenkorb-Screen

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    refreshListenable: ref.watch(routerRefreshProvider),

    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);

      final currentPath = state.uri.path;

      if (authState.isLoading) {
        return null;
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null && user.id.isNotEmpty;

      print('Redirect check: path=$currentPath, isLoggedIn=$isLoggedIn, user=${user?.email}');

      if (!isLoggedIn && currentPath != '/login') {
        print('→ Redirect to /login (not logged in)');
        return '/login';
      }

      if (isLoggedIn && currentPath == '/login') {
        print('→ Redirect to / (logged in)');
        return '/';
      }

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
                builder: (context, state) => const DishesListScreen(),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                name: 'cart',
                builder: (context, state) => const CartScreen(),
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
    final cartAsync = ref.watch(cartProvider);
    final cartItemCount = cartAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          toolbarHeight: 100,
          title: Image.asset(
            'assets/Logo.png',
            height: 80,
            fit: BoxFit.contain,
          ),
          centerTitle: true,
          titleSpacing: 0,
          elevation: 0,
          backgroundColor: Colors.white,
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
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Gerichte',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: cartItemCount > 0,
              label: Text('$cartItemCount'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Warenkorb',
          ),
        ],
      ),
    );
  }
}