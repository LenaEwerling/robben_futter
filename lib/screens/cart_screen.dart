import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../providers/cart_provider.dart';

Future<Map<String, String>> _loadOptionNames(Map<String, dynamic> selectedOptions) async {
  final allOptionIds = <String>{};
  final allGroupIds = selectedOptions.keys.toList();

  Map<String, String> groupNameMap = {};
  if (allGroupIds.isNotEmpty) {
    final groupsResponse = await supabase
        .from('option_groups')
        .select('id, name')
        .inFilter('id', allGroupIds);
    groupNameMap = {for (final g in groupsResponse) g['id'] as String: g['name'] as String};
  }

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

  return {
    ...groupNameMap,
    ...optionNameMap,
  };
}

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  // Lokaler State für Mengen – verhindert Flackern
  late Map<String, int> _localQuantities;

  // Debounce-Timer – speichert nach 800 ms ohne weitere Änderung
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _localQuantities = {};
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Debounce-Funktion: speichert nach 800 ms
  void _debouncedSave(String itemId, int newQty) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      final currentQty = ref.read(cartProvider).valueOrNull?.firstWhereOrNull((i) => i.id == itemId)?.quantity;
      if (currentQty != null && newQty != currentQty) {
        ref.read(cartProvider.notifier).updateQuantity(itemId, newQty);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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

          // Lokale Mengen initialisieren (nur einmal)
          if (_localQuantities.isEmpty) {
            for (final item in items) {
              _localQuantities[item.id] = item.quantity;
            }
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final localQty = _localQuantities[item.id] ?? item.quantity;

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
                          final newQty = localQty > 1 ? localQty - 1 : 0;
                          setState(() {
                            if (newQty > 0) {
                              _localQuantities[item.id] = newQty;
                            } else {
                              _localQuantities.remove(item.id);
                            }
                          });
                          if (newQty > 0) {
                            _debouncedSave(item.id, newQty);
                          } else {
                            ref.read(cartProvider.notifier).removeFromCart(item.id);
                          }
                        },
                      ),
                      Text('$localQty'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final newQty = localQty + 1;
                          setState(() {
                            _localQuantities[item.id] = newQty;
                          });
                          _debouncedSave(item.id, newQty);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
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
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Gewählte Optionen:', style: TextStyle(fontWeight: FontWeight.bold)),

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

                                        if (value is String) {
                                          final optName = nameMap[value] ?? value;
                                          print('  - Single: $optName');
                                          optionLines.add(
                                            Padding(
                                              padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
                                              child: Text('$groupName: $optName'),
                                            ),
                                          );
                                        } else if (value is Iterable) {
                                          final opts = value.map((e) => e.toString()).toList();
                                          print('  - Multi (${opts.length} Optionen): ${opts.join(', ')}');
                                          for (final optId in opts) {
                                            final optName = nameMap[optId] ?? optId;
                                            optionLines.add(
                                              Padding(
                                                padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
                                                child: Text('$groupName: $optName'),
                                              ),
                                            );
                                          }
                                        } else if (value is Map) {
                                          print('  - Quantity (${value.length} Optionen):');
                                          value.forEach((optIdRaw, qtyRaw) {
                                            final optId = optIdRaw.toString();
                                            final qty = (qtyRaw is int) ? qtyRaw : int.tryParse(qtyRaw.toString()) ?? 0;
                                            if (qty > 0) {
                                              final optName = nameMap[optId] ?? optId;
                                              print('    - $optName (${qty}x)');
                                              optionLines.add(
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
                                                  child: Text('$groupName: $optName (${qty}x)'),
                                                ),
                                              );
                                            }
                                          });
                                        } else {
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