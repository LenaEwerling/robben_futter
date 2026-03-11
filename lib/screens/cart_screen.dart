import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../providers/cart_provider.dart';

Future<Map<String, String>> _loadOptionNames(Map<String, dynamic> selectedOptions) async {
  final allOptionIds = <String>{};
  final allGroupIds = selectedOptions.keys.toList(); // Alle Gruppen-IDs sammeln

  // 1. Gruppen-Namen nachladen
  Map<String, String> groupNameMap = {};
  if (allGroupIds.isNotEmpty) {
    final groupsResponse = await supabase
        .from('option_groups')
        .select('id, name')
        .inFilter('id', allGroupIds);
    groupNameMap = {for (final g in groupsResponse) g['id'] as String: g['name'] as String};
  }

  // 2. Option-Namen nachladen
  for (final value in selectedOptions.values) {
    if (value is Iterable) {
      allOptionIds.addAll(value.cast<String>());
    } else if (value is Map) {
      allOptionIds.addAll(value.keys.cast<String>());
    } else if (value is String) {
      allOptionIds.add(value);
    }
  }

  Map<String, String> optionNameMap = {};
  if (allOptionIds.isNotEmpty) {
    final optionsResponse = await supabase
        .from('options')
        .select('id, name')
        .inFilter('id', allOptionIds.toList());
    optionNameMap = {for (final o in optionsResponse) o['id'] as String: o['name'] as String};
  }

  // Debug-Ausgabe (in Konsole schauen!)
  print('Group-Namen: $groupNameMap');
  print('Option-Namen: $optionNameMap');

  return {
    ...groupNameMap,
    ...optionNameMap,
  };
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warenkorb'),
      ),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Fehler: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Warenkorb ist leer'));
          }

          return FutureBuilder<Map<String, String>>(
            future: _loadOptionNames(items.fold<Map<String, dynamic>>(
              {},
                  (map, item) => {...map, ...item.selectedOptions},
            )),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Fehler beim Laden der Optionen: ${snapshot.error}'));
              }

              final nameMap = snapshot.data ?? {};

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ExpansionTile(
                      title: Text(item.dishName),
                      subtitle: Text(item.dishDescription),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (item.quantity > 1) {
                                ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1);
                              } else {
                                ref.read(cartProvider.notifier).removeFromCart(item.id);
                              }
                            },
                          ),
                          Text('${item.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => ref.read(cartProvider.notifier).removeFromCart(item.id),
                          ),
                        ],
                      ),
                      children: [
                        if (item.selectedOptions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: FutureBuilder<Map<String, String>>(
                              future: _loadOptionNames(item.selectedOptions),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Lade Optionen...');
                                }
                                if (snapshot.hasError) {
                                  return Text('Fehler: ${snapshot.error}');
                                }

                                final nameMap = snapshot.data ?? {};

                                return Align(
                                  alignment: Alignment.centerLeft, // ← erzwingt linksbündig
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Gewählte Optionen:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      ...item.selectedOptions.entries.map((entry) {
                                        final groupId = entry.key;
                                        final groupName = nameMap[groupId] ?? groupId;
                                        final value = entry.value;

                                        if (value is Set<String>) {
                                          final names = value.map((id) => nameMap[id] ?? id).join(', ');
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                                            child: Text('$groupName: $names'),
                                          );
                                        } else if (value is Map<String, int>) {
                                          final names = value.entries.map((e) {
                                            final name = nameMap[e.key] ?? e.key;
                                            return '$name (${e.value}x)';
                                          }).join(', ');
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                                            child: Text('$groupName: $names'),
                                          );
                                        } else if (value is String) {
                                          final name = nameMap[value] ?? value;
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                                            child: Text('$groupName: $name'),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      }).toList(),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: cartAsync.value?.isNotEmpty ?? false
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bestellung wird gesendet...')),
            );
          },
          child: const Text('Jetzt bestellen'),
        ),
      )
          : null,
    );
  }
}