import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/dish_detail_provider.dart';
import '../providers/auth_providers.dart';

class DishDetailScreen extends ConsumerWidget {
  final String dishId;

  const DishDetailScreen({super.key, required this.dishId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dishAsync = ref.watch(dishDetailProvider(dishId));
    final groupsAsync = ref.watch(optionGroupsForDishProvider(dishId));

    return Scaffold(
      appBar: AppBar(
        title: Text(dishAsync.value?['name'] ?? 'Gericht laden...'),
      ),
      body: dishAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Fehler: $err')),
        data: (dish) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dishDetailProvider(dishId));
            ref.invalidate(optionGroupsForDishProvider(dishId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Gericht-Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dish['name'], style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(dish['description'] ?? 'Keine Beschreibung'),
                      const SizedBox(height: 8),
                      Text('Zubereitungszeit: ${dish['prep_time_min']} Min.'),
                      Text('Kategorie: ${dish['categories']['name'] ?? 'Unbekannt'}'),
                      // Später: Bild anzeigen, wenn image_url vorhanden
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Optionen-Gruppen
              groupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Text('Optionen-Fehler: $err'),
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Text('Keine Optionen verfügbar');
                  }

                  return Column(
                    children: groups.map((groupData) {
                      final group = groupData.group;
                      final options = groupData.options;
                      final type = group['type'] as String;
                      final required = group['required'] as bool;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Text(
                            group['name'],
                            style: TextStyle(fontWeight: required ? FontWeight.bold : FontWeight.normal),
                          ),
                          subtitle: Text(
                            required ? 'Pflichtfeld' : 'Optional • ${group['description'] ?? ''}',
                            style: TextStyle(color: required ? Colors.red : Colors.grey),
                          ),
                          children: options.map((opt) {
                            return ListTile(
                              title: Text(opt['name']),
                              subtitle: Text(
                                '${opt['portion_size_g'] ?? '?'} ${opt['unit'] ?? 'g'} • '
                                    'Protein: ${opt['protein_per_100g']}g / Carbs: ${opt['carbs_per_100g']}g',
                              ),
                              leading: _buildSelectionWidget(type, opt),
                              onTap: () {
                                // Hier später State für Auswahl managen (siehe unten)
                              },
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Bestell-Button (Platzhalter – Logik kommt als Nächstes)
              FilledButton.icon(
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Bestellen'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bestell-Logik kommt als Nächstes')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionWidget(String type, Map<String, dynamic> option) {
    // Platzhalter – später echte Radio / Checkbox / Quantity
    switch (type) {
      case 'single':
        return const Radio(value: false, groupValue: true, onChanged: null);
      case 'multi':
        return const Checkbox(value: false, onChanged: null);
      case 'quantity':
        return const Icon(Icons.add_circle_outline);
      default:
        return const SizedBox.shrink();
    }
  }
}