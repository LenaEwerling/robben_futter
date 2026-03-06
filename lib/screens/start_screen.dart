// lib/screens/start_screen.dart
import 'package:flutter/material.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RobbenFutter')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Willkommen bei RobbenFutter!'),
            SizedBox(height: 20),
            Text('Supabase ist bereit – lass uns loslegen'),
          ],
        ),
      ),
    );
  }
}