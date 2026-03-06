import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:robben_futter/providers/auth_providers.dart'; // ← hier liegen isAdminProvider & userRoleProvider
import 'package:robben_futter/screens/test_dishes_screen.dart';        // dein TestDishesScreen-Import
import 'package:robben_futter/screens/login_screen.dart';

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hole den Admin-Status aus Riverpod
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RobbenFutter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Ausloggen',
            onPressed: () async {
              await ref.read(authProvider).signOut();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ausgeloggt')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Willkommen bei RobbenFutter!'),
            const SizedBox(height: 20),
            const Text('Supabase ist bereit – lass uns loslegen'),

            const SizedBox(height: 40),

            // 1. Der normale Test-Button (für alle sichtbar)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TestDishesScreen()),
                );
              },
              child: const Text('Gerichte laden & testen'),
            ),
            const SizedBox(height: 20),

            // 2. Der neue Admin-Button (nur für Admin sichtbar / aktiv)
            if (isAdmin)
              ElevatedButton.icon(
                //icon: const Icon(Icons.admin_panelsettings),
                label: const Text('Admin: Neues Gericht anlegen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // Hier kommt später die Admin-Aktion rein, z. B.:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin-Bereich: Hier könntest du Gerichte verwalten'),
                    ),
                  );
                  // Navigator.push(context, MaterialPageRoute(builder: () => AdminDishEditScreen()));
                },
              )
            else
              const Text(
                'Du bist normaler User – Admin-Funktionen ausgeblendet',
                style: TextStyle(color: Colors.grey),
              ),

            // Alternative: Button immer anzeigen, aber deaktivieren
            // ElevatedButton(
            //   onPressed: isAdmin ? () { /* Admin-Aktion */ } : null,
            //   child: const Text('Admin: Neues Gericht'),
            // ),
            const SizedBox(height: 40),

            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Ausloggen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                await ref.read(authProvider).signOut();  // ← dein signOut aus authprovider.dart

                ref.invalidate(authProvider);
                ref.invalidate(userRoleProvider);
                ref.invalidate(isAdminProvider);

                ref.refresh(authProvider);

                // Optional: Zurück zum Login navigieren
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => LoginScreen()
                  ),
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erfolgreich ausgeloggt')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}