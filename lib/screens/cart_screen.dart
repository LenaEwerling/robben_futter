import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../main.dart';
import '../providers/auth_providers.dart';
import '../providers/cart_provider.dart';
import '../providers/dish_detail_provider.dart';

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
  late Map<String, int> _localQuantities;
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
                      // IconButton(
                      //   icon: const Icon(Icons.remove),
                      //   onPressed: () {
                      //     final newQty = localQty > 1 ? localQty - 1 : 0;
                      //     setState(() {
                      //       if (newQty > 0) {
                      //         _localQuantities[item.id] = newQty;
                      //       } else {
                      //         _localQuantities.remove(item.id);
                      //       }
                      //     });
                      //     if (newQty > 0) {
                      //       _debouncedSave(item.id, newQty);
                      //     } else {
                      //       ref.read(cartProvider.notifier).removeFromCart(item.id);
                      //     }
                      //   },
                      // ),
                      Text('$localQty'),
                      // IconButton(
                      //   icon: const Icon(Icons.add),
                      //   onPressed: () {
                      //     final newQty = localQty + 1;
                      //     setState(() {
                      //       _localQuantities[item.id] = newQty;
                      //     });
                      //     _debouncedSave(item.id, newQty);
                      //   },
                      // ),
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

                                      if (selectedOptions.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.only(left: 16, top: 4),
                                          child: Text('Keine Optionen gewählt', style: TextStyle(color: Colors.grey)),
                                        );
                                      }

                                      final List<Widget> optionLines = [];

                                      selectedOptions.forEach((groupId, rawValue) {
                                        final groupName = nameMap[groupId] ?? 'Gruppe $groupId';

                                        dynamic value = rawValue;

                                        if (value is String) {
                                          final optName = nameMap[value] ?? value;
                                          optionLines.add(
                                            Padding(
                                              padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
                                              child: Text('$groupName: $optName'),
                                            ),
                                          );
                                        } else if (value is Iterable) {
                                          final opts = value.map((e) => e.toString()).toList();
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
                                          value.forEach((optIdRaw, qtyRaw) {
                                            final optId = optIdRaw.toString();
                                            final qty = (qtyRaw is int) ? qtyRaw : int.tryParse(qtyRaw.toString()) ?? 0;
                                            if (qty > 0) {
                                              final optName = nameMap[optId] ?? optId;
                                              optionLines.add(
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
                                                  child: Text('$groupName: $optName (${qty}x)'),
                                                ),
                                              );
                                            }
                                          });
                                        } else {
                                          optionLines.add(
                                            Padding(
                                              padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
                                              child: Text('$groupName: [Unbekanntes Format]', style: TextStyle(color: Colors.orange)),
                                            ),
                                          );
                                        }
                                      });

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
          onPressed: () async {
            final items = cartAsync.value ?? [];
            if (items.isEmpty) return;

            try {
              // 1. Alle Pflicht-Checks (pro Item + gesamt)
              for (final item in items) {
                // Hier kannst du später die Limits prüfen (dish.stock, option.stock / qty usw.)
                if (item.quantity <= 0) {
                  throw Exception('Ungültige Menge bei ${item.dishName}');
                }
              }

              // 2. User holen
              final user = ref.read(authNotifierProvider).value;
              if (user == null) throw Exception('Nicht eingeloggt');

              // 3. Items für RPC vorbereiten (korrekte Typen, keine extra Anführungszeichen)
              final List<Map<String, dynamic>> preparedItems = items.map((item) {
                return {
                  'dish_id': item.dishId, // UUID als String (Supabase konvertiert automatisch)
                  'quantity': item.quantity,
                  'selected_options': item.selectedOptions, // JSONB wird automatisch erkannt
                };
              }).toList();

              // 4. RPC aufrufen (process_cart_order)
              final response = await supabase.rpc('process_cart_order', params: {
                'p_user_id': user.id,
                'p_items': preparedItems,
              });

              if (response['success'] != true) {
                throw Exception(response['message'] ?? 'Unbekannter Fehler');
              }

              // Erfolg
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bestellung erfolgreich!'), backgroundColor: Colors.green),
              );

              // Cart leeren
              ref.read(cartProvider.notifier).clearCart();

              // Dish-Provider für alle betroffenen Gerichte invalidieren
              for (final item in items) {
                ref.invalidate(dishDetailProvider(item.dishId));
              }

              // Zurück zur Liste
              context.goNamed('dishes-list');

            } catch (e, st) {
              print('Bestell-Fehler: $e\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fehler beim Bestellen: $e'), backgroundColor: Colors.red),
              );
            }
          },
          child: const Text('Jetzt bestellen'),
        ),
      )
          : null,
    );
  }
}