import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'login_screen.dart';
import 'test_dishes_screen.dart'; // dein TestDishesScreen

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RobbenFutter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Ausloggen',
            onPressed: () async {
              try {
                await ref.read(authProvider).signOut();

                // Navigation zuerst → verhindert Kontext-Probleme nach invalidate
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }

                // Danach State zurücksetzen (auch wenn der alte Kontext weg ist → Riverpod ist global)
                ref.invalidate(userRoleProvider);
                ref.invalidate(isAdminProvider);
                // ref.invalidate(authProvider); // meist nicht nötig, da signOut() das schon triggert

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erfolgreich ausgeloggt')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout fehlgeschlagen: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Willkommen bei RobbenFutter!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Supabase ist bereit – lass uns loslegen'),
            const SizedBox(height: 48),

            // Normaler Button – für alle sichtbar
            ElevatedButton.icon(
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Gerichte laden & testen'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TestDishesScreen()),
                );
              },
            ),
            const SizedBox(height: 32),

            // Admin-spezifischer Bereich
            if (isAdmin)
              ElevatedButton.icon(
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Admin: Neues Gericht anlegen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin-Bereich: Gerichte verwalten (zukünftig)'),
                    ),
                  );
                  // Später: Navigator.push(... AdminDishEditScreen());
                },
              )
            else
              const Text(
                'Du bist normaler User – Admin-Funktionen ausgeblendet',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }
}