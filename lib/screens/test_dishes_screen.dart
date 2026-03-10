// lib/screens/test_dishes_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class TestDishesScreen extends StatefulWidget {
  TestDishesScreen({super.key});

  @override
  State<TestDishesScreen> createState() => _TestDishesScreenState();
}

class _TestDishesScreenState extends State<TestDishesScreen> {
  List<Map<String, dynamic>> _dishes = [];
  String _status = 'Lade Gerichte...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    try {
      final response = await supabase
          .from('dishes')
          .select('id, name, description, is_available, prep_time_min')
          //.eq('is_available', true)
          .limit(10);

      setState(() {
        _dishes = List<Map<String, dynamic>>.from(response);
        _status = 'Geladene Gerichte: ${_dishes.length}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Fehler: $e';
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SealFood – Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Willkommen bei SealFood!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (_isLoading)
            const CircularProgressIndicator()
            else if (_dishes.isEmpty)
            const Text('Keine verfügbaren Gerichte gefunden.')
            else
            Expanded(
              child: ListView.builder(
                itemCount: _dishes.length,
                itemBuilder: (context, index) {
                  final dish = _dishes[index];
                  return ListTile(
                    title: Text(dish['name'] ?? 'Unbekannt'),
                    subtitle: Text(
                      '${dish['description'] ?? ''}\n'
                      'Zubereitung: ${dish['prep_time_min'] ?? '?'} Min • Verfügbar: ${dish['is_available']}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}