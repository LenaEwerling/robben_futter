import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' show min;

import '../providers/auth_providers.dart' hide supabase;
import '../providers/dish_detail_provider.dart';
import '../providers/selection_provider.dart';
import '../main.dart'; // supabase client

class DishDetailScreen extends ConsumerStatefulWidget {
  final String dishId;

  const DishDetailScreen({super.key, required this.dishId});

  @override
  ConsumerState<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends ConsumerState<DishDetailScreen> {
  bool _quantityWasAutoReduced = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final groups = ref.read(optionGroupsForDishProvider(widget.dishId)).value ?? [];
      final notifier = ref.read(selectionProvider(widget.dishId).notifier);

      for (final groupData in groups) {
        final group = groupData.group;
        final type = group['type'] as String;
        final minSel = group['min_selections'] as int? ?? 0;
        final groupId = group['id'] as String;

        if (minSel > 0 && notifier.state.selections[groupId] == null) {
          if (type == 'single' || type == 'multi') {
            final firstOptId = groupData.options.firstOrNull?['id'] as String?;
            if (firstOptId != null) {
              if (type == 'single') {
                notifier.selectSingle(groupId, firstOptId);
              } else if (type == 'multi') {
                notifier.toggleMulti(groupId, firstOptId);
              }
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dishAsync = ref.watch(dishDetailProvider(widget.dishId));
    final groupsAsync = ref.watch(optionGroupsForDishProvider(widget.dishId));
    final selection = ref.watch(selectionProvider(widget.dishId));

    return Scaffold(
      appBar: AppBar(
        title: Text(dishAsync.value?['name'] ?? 'Gericht laden...'),
      ),
      body: dishAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Fehler: $err')),
        data: (dish) {
          // Basis-Limit vom Gericht selbst
          final dishStock = dish['stock_quantity'] as int? ?? 999999;
          final ignoreCat = dish['ignore_category_stock'] as bool? ?? false;
          final catStockRaw = dish['categories']?['stock_quantity'] as int?;

          int currentLimit = dishStock;

          if (catStockRaw != null && !ignoreCat) {
            currentLimit = min(currentLimit, catStockRaw);
          }

          // Optionen-Limit nur aus ausgewählten Optionen (min über portionsPossible)
          final groups = groupsAsync.value ?? [];
          int optionLimit = 999999;

          final selectedQuantities = selection.selections.entries
              .where((entry) => entry.value is Map<String, int>)
              .expand((entry) => (entry.value as Map<String, int>).entries)
              .toList();

          for (final groupData in groups) {
            for (final opt in groupData.options) {
              final optId = opt['id'] as String;
              final optQtyEntry = selectedQuantities.firstWhereOrNull((q) => q.key == optId);
              if (optQtyEntry != null) {
                final optQty = optQtyEntry.value;
                if (optQty > 0) {
                  final optStock = opt['stock_quantity'] as int? ?? 999999;
                  final portionsPossible = optStock ~/ optQty;
                  optionLimit = min(optionLimit, portionsPossible);
                }
              }
            }
          }

          final effectiveMax = min(currentLimit, optionLimit);

          final currentQty = selection.dishQuantity ?? 1;
          final displayQty = currentQty > effectiveMax ? effectiveMax : currentQty;

          // Automatische Anpassung + Flag setzen
          if (currentQty > effectiveMax) {
            _quantityWasAutoReduced = true;
            Future.microtask(() {
              ref.read(selectionProvider(widget.dishId).notifier)
                  .updateDishQuantity(effectiveMax);
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dish['name'], style: Theme.of(context).textTheme.headlineMedium),
                      Text(dish['description'] ?? 'Keine Beschreibung'),
                      Text('Zubereitungszeit: ${dish['prep_time_min']} Min.'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text(
                        'Menge:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: displayQty > 1
                            ? () {
                          setState(() => _quantityWasAutoReduced = false);
                          ref.read(selectionProvider(widget.dishId).notifier)
                              .updateDishQuantity(displayQty - 1);
                        }
                            : null,
                      ),
                      SizedBox(
                        width: 60,
                        child: Center(
                          child: Text(
                            '$displayQty',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _quantityWasAutoReduced ? Colors.red : null,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: displayQty < effectiveMax ? null : Colors.grey,
                        ),
                        onPressed: displayQty < effectiveMax
                            ? () {
                          setState(() => _quantityWasAutoReduced = false);
                          ref.read(selectionProvider(widget.dishId).notifier)
                              .updateDishQuantity(displayQty + 1);
                        }
                            : null,
                      ),
                      const SizedBox(width: 12),
                      if (effectiveMax < 999999)
                        Text(
                          '(max. $effectiveMax)',
                          style: TextStyle(
                            color: _quantityWasAutoReduced ? Colors.red : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              groupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Text('Optionen-Fehler: $err'),
                data: (groups) {
                  if (groups.isEmpty) return const Text('Keine Optionen');

                  return Column(
                    children: groups.map((groupData) {
                      final group = groupData.group;
                      final options = groupData.options;
                      final type = group['type'] as String;
                      final required = group['required'] as bool;
                      final minSel = group['min_selections'] as int? ?? 0;
                      final maxSel = group['max_selections'] as int?;
                      final groupId = group['id'] as String;

                      final currentSelection = selection.selections[groupId];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Text(
                            group['name'],
                            style: TextStyle(fontWeight: required ? FontWeight.bold : FontWeight.normal),
                          ),
                          subtitle: Text(
                            required
                                ? 'Pflicht · min $minSel${maxSel != null ? ' · max $maxSel' : ''}'
                                : 'Optional',
                            style: TextStyle(color: required ? Colors.red : Colors.grey),
                          ),
                          children: options.map((opt) {
                            final optId = opt['id'] as String;
                            final optName = opt['name'] as String;
                            final optDesc = opt['description'] as String?;
                            final maxQty = opt['max_quantity'] as int?;
                            final optStock = opt['stock_quantity'] as int? ?? 999999;

                            late Widget control;

                            switch (type) {
                              case 'single':
                                final isSelected = currentSelection == optId;
                                control = Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Radio<String>(
                                      value: optId,
                                      groupValue: currentSelection as String?,
                                      onChanged: (value) {
                                        ref.read(selectionProvider(widget.dishId).notifier)
                                            .selectSingle(groupId, value!);
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(optName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          if (optDesc != null && optDesc.isNotEmpty)
                                            Text(
                                              optDesc,
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                break;

                              case 'multi':
                                final selectedSet = currentSelection as Set<String>? ?? {};
                                final isSelected = selectedSet.contains(optId);
                                final currentCount = selectedSet.length;
                                final reachedMax = maxSel != null && currentCount >= maxSel && !isSelected;

                                control = Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: reachedMax
                                          ? null
                                          : (bool? value) {
                                        ref.read(selectionProvider(widget.dishId).notifier)
                                            .toggleMulti(groupId, optId);
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(optName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          if (optDesc != null && optDesc.isNotEmpty)
                                            Text(
                                              optDesc,
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                break;

                              case 'quantity':
                                final quantities = currentSelection as Map<String, int>? ?? {};
                                final qty = quantities[optId] ?? 0;

                                final maxFromConfig = maxQty ?? 999999;
                                final maxFromStock = optStock;
                                final effectiveOptionMax = min(maxFromConfig, maxFromStock);

                                final canIncrease = qty < effectiveOptionMax;

                                control = Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: qty > 0
                                          ? () => ref.read(selectionProvider(widget.dishId).notifier)
                                          .updateQuantity(groupId, optId, qty - 1)
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$qty',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        color: canIncrease ? null : Colors.grey,
                                      ),
                                      onPressed: canIncrease
                                          ? () => ref.read(selectionProvider(widget.dishId).notifier)
                                          .updateQuantity(groupId, optId, qty + 1)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(optName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          if (optDesc != null && optDesc.isNotEmpty)
                                            Text(
                                              optDesc,
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          Text(
                                            '(max. $effectiveOptionMax)',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                break;

                              default:
                                control = Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 48),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(optName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          if (optDesc != null && optDesc.isNotEmpty)
                                            Text(optDesc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              child: control,
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 40),

              FilledButton.icon(
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Bestellen'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final groups = groupsAsync.value ?? [];
                  final notifier = ref.read(selectionProvider(widget.dishId).notifier);

                  final allValid = notifier.areAllGroupsValid(groups);
                  if (!allValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bitte alle Pflichtfelder und Begrenzungen einhalten'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    final user = ref.read(authNotifierProvider).value;
                    if (user == null) throw Exception('Nicht eingeloggt');

                    final orderResponse = await supabase
                        .from('orders')
                        .insert({
                      'user_id': user.id,
                      'status': 'new',
                      'notes': 'Bestellt über App',
                    })
                        .select('id')
                        .single();

                    final orderId = orderResponse['id'] as String;

                    final orderItemResponse = await supabase
                        .from('order_items')
                        .insert({
                      'order_id': orderId,
                      'dish_id': widget.dishId,
                      'quantity': selection.dishQuantity ?? 1,
                    })
                        .select('id')
                        .single();

                    final orderItemId = orderItemResponse['id'] as String;

                    final selections = notifier.state.selections;
                    final List<Map<String, dynamic>> optionInserts = [];

                    for (final entry in selections.entries) {
                      final groupId = entry.key;
                      final selectionValue = entry.value;

                      if (selectionValue is String) {
                        optionInserts.add({
                          'order_item_id': orderItemId,
                          'option_id': selectionValue,
                          'quantity': 1,
                          'selected': true,
                        });
                      } else if (selectionValue is Set<String>) {
                        for (final optId in selectionValue) {
                          optionInserts.add({
                            'order_item_id': orderItemId,
                            'option_id': optId,
                            'quantity': 1,
                            'selected': true,
                          });
                        }
                      } else if (selectionValue is Map<String, int>) {
                        for (final optEntry in selectionValue.entries) {
                          optionInserts.add({
                            'order_item_id': orderItemId,
                            'option_id': optEntry.key,
                            'quantity': optEntry.value,
                            'selected': optEntry.value > 0,
                          });
                        }
                      }
                    }

                    if (optionInserts.isNotEmpty) {
                      await supabase.from('order_item_options').insert(optionInserts);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bestellung erfolgreich gespeichert!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    notifier.state = const SelectionState();
                    context.goNamed('dishes-list');

                  } catch (e, stack) {
                    print('Bestell-Fehler: $e\n$stack');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Fehler beim Speichern: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}