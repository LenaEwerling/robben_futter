import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart'; // supabase client

// Modell-Klasse für eine Optionen-Gruppe inkl. ihrer Optionen
class OptionGroupWithOptions {
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> options;

  OptionGroupWithOptions(this.group, this.options);
}

// Einzelnes Gericht laden (inkl. Kategorie-Name)
final dishDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, dishId) async {
  final response = await supabase
      .from('dishes')
      .select('*, categories!inner(name)')
      .eq('id', dishId)
      .single();

  return response;
});

// Robuste Variante: Optionen-Gruppen + Optionen separat laden
final optionGroupsForDishProvider = FutureProvider.family<List<OptionGroupWithOptions>, String>((ref, dishId) async {
  try {
    // Schritt 1: Alle Optionen-Gruppen für diesen Dish holen (inkl. Gruppen-Details)
    final groupsResponse = await supabase
        .from('dish_option_groups')
        .select('''
          option_group_id,
          sort_order,
          option_groups!inner (
            id,
            name,
            type,
            required,
            description,
            sort_order
          )
        ''')
        .eq('dish_id', dishId)
        .order('sort_order');

    final List<OptionGroupWithOptions> result = [];

    for (final groupRow in groupsResponse) {
      final groupId = groupRow['option_group_id'] as String;
      final groupData = groupRow['option_groups'] as Map<String, dynamic>;

      // Schritt 2: Alle Optionen für diese Gruppe holen
      final optionsResponse = await supabase
          .from('options')
          .select('''
            id,
            name,
            description,
            price_adjust,
            default_selected,
            sort_order,
            is_available,
            protein_per_100g,
            carbs_per_100g,
            gi,
            gl,
            portion_size_g,
            unit
          ''')
          .eq('group_id', groupId)
          .order('sort_order');

      result.add(OptionGroupWithOptions(groupData, optionsResponse));
    }

    // Optional: Gruppen nach sort_order sortieren (falls Supabase das nicht tut)
    result.sort((a, b) {
      final aSort = a.group['sort_order'] as int? ?? 0;
      final bSort = b.group['sort_order'] as int? ?? 0;
      return aSort.compareTo(bSort);
    });

    return result;
  } catch (e, stack) {
    print('Fehler beim Laden der Optionen: $e');
    print(stack);
    rethrow;
  }
});