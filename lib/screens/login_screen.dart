import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart'; // ← falls du SVG nutzt, sonst Image.asset

import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Nur den Notifier verwenden – nicht den Service direkt aufrufen
      await ref.read(authNotifierProvider.notifier).signIn(
        _emailCtrl.text.trim(),
        _pwCtrl.text.trim(),
      );

      // Optional: kurz warten, bis der State nicht mehr loading ist
      while (ref.read(authNotifierProvider).isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Navigation nur einmal und nur wenn erfolgreich
      if (context.mounted) {
        context.goNamed('home');
      }
    } catch (e) {
      String msg;
      if (e.toString().contains('Invalid login credentials')) {
        msg = 'Falsche E-Mail oder Passwort';
      } else {
        msg = 'Login fehlgeschlagen: $e';
      }

      if (context.mounted) {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true, // ← Tastatur schiebt Inhalt hoch
      body: SafeArea(
        child: SingleChildScrollView(
          reverse: true, // ← Scrollt nach unten, wenn Tastatur kommt
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: keyboardHeight > 0 ? 150 : 300, // ← Logo schrumpft bei Tastatur
                child: Image.asset(  // ← oder Image.asset('assets/Logo.png', ...)
                  'assets/Logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'E-Mail'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwCtrl,
                decoration: const InputDecoration(labelText: 'Passwort'),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Einloggen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }
}