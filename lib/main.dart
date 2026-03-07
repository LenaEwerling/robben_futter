import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart'; // ← neu!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ctonwlszpcnondzknwln.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0b253bHN6cGNub25kemtud2xuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3MjA3MjAsImV4cCI6MjA4ODI5NjcyMH0.ZvPvCdQgRjcnfVbySDLZVfGktdkAPpgTCIHPzDYM_sY',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'RobbenFutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: router,
      // Entferne home & onGenerateRoute etc. – alles geht über router
    );
  }
}

final supabase = Supabase.instance.client;