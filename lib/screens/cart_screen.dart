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
                            padding: const EdgeInsets.all(16),
                            child: FutureBuilder<Map<String, String>>(
                              future: _loadOptionNames(item.selectedOptions),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Lade Optionen...');
                                }
                                if (snapshot.hasError) {
                                  return Text('Fehler beim Laden der Optionen: ${snapshot.error}');
                                }

                                final nameMap = snapshot.data ?? {};

                                return Align(
                                  alignment: Alignment.centerLeft, // ← das sorgt für garantiert linksbündig
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Gewählte Optionen:', style: TextStyle(fontWeight: FontWeight.bold)),

                                      // Einmaliger, sauberer Abstand vor der Liste
                                      const SizedBox(height: 12),

                                      Builder(
                                        builder: (context) {
                                          final selectedOptions = item.selectedOptions;
                                          print('=== DEBUG: selectedOptions für Item ${item.id} ===');
                                          print('Rohdaten: $selectedOptions');
                                          print('Anzahl Gruppen: ${selectedOptions.length}');

                                          if (selectedOptions.isEmpty) {
                                            print('Keine Optionen ausgewählt');
                                            return const Padding(
                                              padding: EdgeInsets.only(left: 16, top: 4),
                                              child: Text('Keine Optionen gewählt', style: TextStyle(color: Colors.grey)),
                                            );
                                          }

                                          final List<Widget> optionLines = [];

                                          selectedOptions.forEach((groupId, rawValue) {
                                            final groupName = nameMap[groupId] ?? 'Gruppe $groupId';
                                            print('Gruppe: $groupName (ID: $groupId) - Typ: ${rawValue.runtimeType}');

                                            dynamic value = rawValue;

                                            // Single: String
                                            if (value is String) {
                                              final optName = nameMap[value] ?? value;
                                              print('  - Single: $optName');
                                              optionLines.add(
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4), // ← einheitlich 32
                                                  child: Text('$groupName: $optName'),
                                                ),
                                              );
                                            }
                                            // Multi: Iterable (List oder Set)
                                            else if (value is Iterable) {
                                              final opts = value.map((e) => e.toString()).toList();
                                              print('  - Multi (${opts.length} Optionen): ${opts.join(', ')}');
                                              for (final optId in opts) {
                                                final optName = nameMap[optId] ?? optId;
                                                optionLines.add(
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2), // ← einheitlich 32
                                                    child: Text('$groupName: $optName'),
                                                  ),
                                                );
                                              }
                                            }
                                            // Quantity: Map
                                            else if (value is Map) {
                                              print('  - Quantity (${value.length} Optionen):');
                                              value.forEach((optIdRaw, qtyRaw) {
                                                final optId = optIdRaw.toString();
                                                final qty = (qtyRaw is int) ? qtyRaw : int.tryParse(qtyRaw.toString()) ?? 0;
                                                if (qty > 0) {
                                                  final optName = nameMap[optId] ?? optId;
                                                  print('    - $optName (${qty}x)');
                                                  optionLines.add(
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2), // ← einheitlich 32
                                                      child: Text('$groupName: $optName (${qty}x)'),
                                                    ),
                                                  );
                                                }
                                              });
                                            }
                                            else {
                                              print('  - Unbekannter Typ: ${value.runtimeType} - $value');
                                              optionLines.add(
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
                                                  child: Text('$groupName: [Unbekanntes Format]', style: TextStyle(color: Colors.orange)),
                                                ),
                                              );
                                            }
                                          });

                                          print('Gesamt Optionen-Zeilen: ${optionLines.length}');
                                          print('=== DEBUG Ende ===');

                                          if (optionLines.isEmpty) {
                                            return const Padding(
                                              padding: EdgeInsets.only(left: 16, top: 4),
                                              child: Text('Keine ausgewählten Optionen', style: TextStyle(color: Colors.grey)),
                                            );
                                          }

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: optionLines,
                                          );
                                        },
                                      ),
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