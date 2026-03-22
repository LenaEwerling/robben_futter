import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ctonwlszpcnondzknwln.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0b253bHN6cGNub25kemtud2xuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3MjA3MjAsImV4cCI6MjA4ODI5NjcyMH0.ZvPvCdQgRjcnfVbySDLZVfGktdkAPpgTCIHPzDYM_sY',
  );

  // Realtime-Subscriptions einmalig einrichten
  final supabase = Supabase.instance.client;

  // Dish-Änderungen abonnieren (für DishDetailScreen)
  supabase.channel('dish-changes')
      .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'dishes',
    callback: (payload) {
      print('Dish geändert: ${payload.newRecord['id']}');
      // Optional: ref.invalidate(dishDetailProvider(payload.newRecord['id'] as String));
    },
  )
      .subscribe();

  // Optional: Optionen-Änderungen abonnieren (für Quantity-Optionen)
  supabase.channel('option-changes')
      .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'options',
    callback: (payload) {
      print('Option geändert: ${payload.newRecord['id']}');
    },
  )
      .subscribe();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'SealFood',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

final supabase = Supabase.instance.client;