import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart'; // supabase client
import 'dish_detail_screen.dart'; // falls noch nicht importiert

final dishesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await supabase
      .from('dishes')
      .select('*, categories!inner(name)')
      .order('name');
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await supabase
      .from('categories')
      .select('id, name')
      .order('name');
});

class DishesListScreen extends ConsumerStatefulWidget {
  const DishesListScreen({super.key});

  @override
  ConsumerState<DishesListScreen> createState() => _DishesListScreenState();
}

class _DishesListScreenState extends ConsumerState<DishesListScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  bool _showUnavailable = false;

  @override
  Widget build(BuildContext context) {
    final dishesAsync = ref.watch(dishesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      body: Column(
        children: [
          // Filter-Leiste
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Suchfeld (ganze Breite)
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Gericht suchen...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
                const SizedBox(height: 12),

                // Checkbox darunter
                CheckboxListTile(
                  title: const Text('Auch nicht verfügbare Gerichte anzeigen'),
                  value: _showUnavailable,
                  onChanged: (val) => setState(() => _showUnavailable = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),

                // Kategorie-Chips (horizontal scrollbar)
                categoriesAsync.when(
                  data: (categories) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Alle'),
                            selected: _selectedCategory == null,
                            onSelected: (_) => setState(() => _selectedCategory = null),
                          ),
                          ...categories.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: Text(cat['name']),
                                selected: _selectedCategory == cat['id'].toString(),
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = selected ? cat['id'].toString() : null;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Kategorien-Fehler: $e'),
                ),
              ],
            ),
          ),

          // Liste
          Expanded(
            child: dishesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Fehler beim Laden: $err')),
              data: (allDishes) {
                // Filter anwenden
                var filtered = allDishes.where((dish) {
                  final nameMatch = (dish['name'] as String).toLowerCase().contains(_searchQuery);
                  final categoryMatch = _selectedCategory == null ||
                      dish['category_id'].toString() == _selectedCategory;
                  final availabilityMatch = _showUnavailable || (dish['is_available'] == true);

                  return nameMatch && categoryMatch && availabilityMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Keine Gerichte gefunden'));
                }

                // Nach Kategorie gruppieren
                final Map<String, List<Map<String, dynamic>>> grouped = {};
                for (var dish in filtered) {
                  final catName = dish['categories']['name'] as String? ?? 'Ohne Kategorie';
                  grouped.putIfAbsent(catName, () => []).add(dish);
                }

                return ListView.builder(
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final catName = grouped.keys.elementAt(index);
                    final dishesInCat = grouped[catName]!;

                    return ExpansionTile(
                      title: Text(
                        catName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      initiallyExpanded: true,
                      children: dishesInCat.map((dish) {
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: InkWell(
                            onTap: () {
                              context.goNamed(
                                'dish-detail',
                                pathParameters: {'id': dish['id'].toString()},
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Foto / Placeholder
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: dish['image_url'] != null
                                        ? Image.network(
                                      dish['image_url'],
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _placeholderImage(),
                                    )
                                        : _placeholderImage(),
                                  ),
                                  const SizedBox(width: 16),

                                  // Infos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dish['name'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dish['description'] ?? 'Keine Beschreibung',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey[700]),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text('${dish['prep_time_min']} Min.'),
                                            const SizedBox(width: 16),
                                            if (!(dish['is_available'] == true))
                                              const Chip(
                                                label: Text('Nicht verfügbar'),
                                                backgroundColor: Colors.red,
                                                labelStyle: TextStyle(color: Colors.white),
                                                padding: EdgeInsets.zero,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[300],
      child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
    );
  }
}