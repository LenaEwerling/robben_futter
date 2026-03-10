import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../app_router.dart'; // für context.go

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Willkommen bei SealFood!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Supabase ist bereit – lass uns loslegen'),
          const SizedBox(height: 48),

          ElevatedButton.icon(
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Gerichte laden & testen'),
            onPressed: () {
              context.goNamed('dishes'); // ← typ-sichere Navigation
            },
          ),
          const SizedBox(height: 32),

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
              },
            )
          else
            const Text(
              'Du bist normaler User – Admin-Funktionen ausgeblendet',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}