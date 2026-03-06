import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robben_futter/screens/start_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ctonwlszpcnondzknwln.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0b253bHN6cGNub25kemtud2xuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3MjA3MjAsImV4cCI6MjA4ODI5NjcyMH0.ZvPvCdQgRjcnfVbySDLZVfGktdkAPpgTCIHPzDYM_sY',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RobbenFutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const StartScreen(), // später dein Login oder Dashboard
    );
  }
}

// Hilfs-Getter für einfachen Zugriff
final supabase = Supabase.instance.client;