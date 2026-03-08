import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dish_detail_provider.dart';

// Modell für ausgewählte Optionen pro Gruppe
class SelectionState {
  final Map<String, dynamic> selections;          // Optionen wie bisher
  final int dishQuantity;                         // ← neu: Menge des Gerichts selbst

  const SelectionState({
    this.selections = const {},
    this.dishQuantity = 1,
  });

  SelectionState copyWith({
    Map<String, dynamic>? selections,
    int? dishQuantity,
  }) {
    return SelectionState(
      selections: selections ?? this.selections,
      dishQuantity: dishQuantity ?? this.dishQuantity,
    );
  }
}

// Family-Notifier: pro dishId ein eigener State
final selectionProvider = NotifierProvider.family<SelectionNotifier, SelectionState, String>(
  SelectionNotifier.new,
);

class SelectionNotifier extends FamilyNotifier<SelectionState, String> {
  @override
  SelectionState build(String dishId) {
    return const SelectionState();
  }

  void updateDishQuantity(int quantity) {
    state = state.copyWith(dishQuantity: quantity.clamp(1, 20)); // z. B. max 20, anpassbar
  }

  void selectSingle(String groupId, String optionId) {
    state = state.copyWith(
      selections: {
        ...state.selections,
        groupId: optionId,
      },
    );
  }

  void toggleMulti(String groupId, String optionId) {
    final current = state.selections[groupId] as Set<String>? ?? <String>{};
    final updated = current.contains(optionId)
        ? current.where((id) => id != optionId).toSet()
        : {...current, optionId};

    state = state.copyWith(
      selections: {
        ...state.selections,
        groupId: updated,
      },
    );
  }

  void updateQuantity(String groupId, String optionId, int quantity) {
    final current = state.selections[groupId] as Map<String, int>? ?? {};
    final updated = Map<String, int>.from(current);
    if (quantity > 0) {
      updated[optionId] = quantity;
    } else {
      updated.remove(optionId);
    }

    state = state.copyWith(
      selections: {
        ...state.selections,
        groupId: updated,
      },
    );
  }

  bool isGroupComplete(String groupId, bool required, List<Map<String, dynamic>> options) {
    final selection = state.selections[groupId];
    if (!required) return true;

    if (selection == null) return false;

    if (selection is String) return selection.isNotEmpty;
    if (selection is Set<String>) return selection.isNotEmpty;
    if (selection is Map<String, int>) return selection.values.any((q) => q > 0);

    return false;
  }

  bool isGroupValid(String groupId, Map<String, dynamic> group, List<Map<String, dynamic>> options) {
    final required = group['required'] as bool? ?? false;
    final minSel = group['min_selections'] as int? ?? 0;
    final maxSel = group['max_selections'] as int?;
    final type = group['type'] as String;

    final selection = state.selections[groupId];

    if (!required && selection == null) return true;

    int count = 0;
    if (type == 'single') {
      count = (selection as String?) != null ? 1 : 0;
    } else if (type == 'multi') {
      count = (selection as Set<String>?)?.length ?? 0;
    } else if (type == 'quantity') {
      final qtyMap = selection as Map<String, int>? ?? {};
      count = qtyMap.values.fold(0, (sum, q) => sum + q);
    }

    // Mindestanzahl prüfen
    if (count < minSel) return false;

    // Maximalanzahl prüfen (wenn gesetzt)
    if (maxSel != null && count > maxSel) return false;

    // Bei quantity: einzelne Optionen dürfen max_quantity nicht überschreiten
    if (type == 'quantity') {
      final qtyMap = selection as Map<String, int>? ?? {};
      for (final opt in options) {
        final optId = opt['id'] as String;
        final maxQty = opt['max_quantity'] as int?;
        final currentQty = qtyMap[optId] ?? 0;
        if (maxQty != null && currentQty > maxQty) {
          return false;
        }
      }
    }

    return true;
  }

  /// Prüft ALLE Gruppen auf Gültigkeit
  bool areAllGroupsValid(List<OptionGroupWithOptions> groups) {
    for (final g in groups) {
      if (!isGroupValid(
        g.group['id'] as String,
        g.group,
        g.options,
      )) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> getAllSelections() => state.selections;
}