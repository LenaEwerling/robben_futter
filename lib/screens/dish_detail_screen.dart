import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  @override
  void initState() {
    super.initState();
    // Initiale Auswahl setzen (bei min_selections > 0 erste Option wählen)
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
        data: (dish) => ListView(
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
                    Text(dish['description'] ?? 'Keine Beschreibung'),
                    Text('Zubereitungszeit: ${dish['prep_time_min']} Min.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mengen-Auswahl für das Gericht selbst
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
                      onPressed: (selection.dishQuantity ?? 1) > 1
                          ? () => ref.read(selectionProvider(widget.dishId).notifier)
                          .updateDishQuantity((selection.dishQuantity ?? 1) - 1)
                          : null,
                    ),
                    SizedBox(
                      width: 60,
                      child: Center(
                        child: Text(
                          '${selection.dishQuantity ?? 1}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => ref.read(selectionProvider(widget.dishId).notifier)
                          .updateDishQuantity((selection.dishQuantity ?? 1) + 1),
                    ),
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

                          Widget control;

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
                              final canIncrease = maxQty == null || qty < maxQty;

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
                                  Text('$qty', style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
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
                                  const SizedBox(width: 48), // Platzhalter
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

                // Validierung
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
                  // 1. Aktuellen User holen
                  final user = ref.read(authNotifierProvider).value;
                  if (user == null) throw Exception('Nicht eingeloggt');

                  // 2. Neue Bestellung erstellen
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

                  // 3. Order-Item für dieses Gericht (mit Menge!)
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

                  // 4. Alle ausgewählten Optionen speichern
                  final selections = notifier.state.selections;
                  final List<Map<String, dynamic>> optionInserts = [];

                  for (final entry in selections.entries) {
                    final groupId = entry.key;
                    final selectionValue = entry.value;

                    if (selectionValue is String) {
                      // single
                      optionInserts.add({
                        'order_item_id': orderItemId,
                        'option_id': selectionValue,
                        'quantity': 1,
                        'selected': true,
                      });
                    } else if (selectionValue is Set<String>) {
                      // multi
                      for (final optId in selectionValue) {
                        optionInserts.add({
                          'order_item_id': orderItemId,
                          'option_id': optId,
                          'quantity': 1,
                          'selected': true,
                        });
                      }
                    } else if (selectionValue is Map<String, int>) {
                      // quantity
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

                  // 5. Erfolg
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bestellung erfolgreich gespeichert!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Reset + zurück
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
        ),
      ),
    );
  }
}