import 'package:flutter/material.dart';
import 'package:robben_futter/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robben_futter/screens/start_screen.dart';
import 'package:robben_futter/providers/auth_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ctonwlszpcnondzknwln.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0b253bHN6cGNub25kemtud2xuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3MjA3MjAsImV4cCI6MjA4ODI5NjcyMH0.ZvPvCdQgRjcnfVbySDLZVfGktdkAPpgTCIHPzDYM_sY',
  );

  runApp(
      const ProviderScope(
          child: MyApp()
      )
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authProvider);

    return MaterialApp(
      title: 'RobbenFutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // Wenn User eingeloggt → Home/Dashboard
          if (snapshot.hasData) {
            return const StartScreen();  // oder dein Dashboard
          }

          // Sonst → Login
          return const LoginScreen();
        },
      ),
    );
  }
}


// Hilfs-Getter für einfachen Zugriff
final supabase = Supabase.instance.client;