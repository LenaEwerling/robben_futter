import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'auth_providers.dart';

class CartItem {
  final String id;
  final String dishId;
  final int quantity;
  final Map<String, dynamic> selectedOptions; // jetzt mit Namen statt IDs
  final DateTime createdAt;
  final String dishName;
  final String dishDescription;

  CartItem({
    required this.id,
    required this.dishId,
    required this.quantity,
    required this.selectedOptions,
    required this.createdAt,
    required this.dishName,
    required this.dishDescription,
  });

  static Future<CartItem> fromJson(Map<String, dynamic> json) async {
    final dish = json['dishes'] as Map<String, dynamic>? ?? {};
    final rawOptions = json['selected_options'] as Map<String, dynamic>? ?? {};

    // Option-Namen nachladen
    final resolvedOptions = <String, dynamic>{};

    for (final entry in rawOptions.entries) {
      final groupName = entry.key;
      final value = entry.value;

      if (value is List || value is Set) {
        final optionIds = (value as Iterable).cast<String>().toList();
        if (optionIds.isEmpty) continue;

        final optionsResponse = await supabase
            .from('options')
            .select('id, name')
            .inFilter('id', optionIds);

        final nameMap = {for (final o in optionsResponse) o['id'] as String: o['name'] as String};

        resolvedOptions[groupName] = optionIds.map((id) => nameMap[id] ?? id).toList();
      } else if (value is Map) {
        // Quantity: {optId: qty}
        final qtyMap = value as Map<String, dynamic>;
        final optionIds = qtyMap.keys.toList();

        final optionsResponse = await supabase
            .from('options')
            .select('id, name')
            .inFilter('id', optionIds);

        final nameMap = {for (final o in optionsResponse) o['id'] as String: o['name'] as String};

        resolvedOptions[groupName] = qtyMap.map((id, qty) => MapEntry(
          nameMap[id] ?? id,
          qty,
        ));
      } else {
        resolvedOptions[groupName] = value;
      }
    }

    return CartItem(
      id: json['id'],
      dishId: json['dish_id'],
      quantity: json['quantity'],
      selectedOptions: resolvedOptions,
      createdAt: DateTime.parse(json['created_at']),
      dishName: dish['name'] ?? 'Unbekanntes Gericht',
      dishDescription: dish['description'] ?? '',
    );
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<List<CartItem>>>((ref) {
  return CartNotifier(ref);
});

class CartNotifier extends StateNotifier<AsyncValue<List<CartItem>>> {
  final Ref ref;

  CartNotifier(this.ref) : super(const AsyncLoading()) {
    _loadCart();
  }

  Future<void> _loadCart() async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authNotifierProvider).value;
      if (user == null) {
        state = const AsyncData([]);
        return;
      }

      final response = await supabase
          .from('cart_items')
          .select('*, dishes!inner(name, description)')
          .eq('user_id', user.id)
          .order('created_at');

      final items = <CartItem>[];
      for (final json in response) {
        final item = await CartItem.fromJson(json);
        items.add(item);
      }
      state = AsyncData(items);
    } catch (e, st) {
      print('Cart-Lade-Fehler: $e');
      state = AsyncError(e, st);
    }
  }

  Future<void> addToCart(String dishId, int quantity, Map<String, dynamic> selectedOptions) async {
    try {
      final user = ref.read(authNotifierProvider).value;
      if (user == null) throw Exception('Nicht eingeloggt');

      // Set → List umwandeln (Supabase kann List in JSONB speichern)
      final serializableOptions = selectedOptions.map((key, value) {
        if (value is Set) {
          return MapEntry(key, value.toList());
        }
        return MapEntry(key, value);
      });

      await supabase.from('cart_items').insert({
        'user_id': user.id,
        'dish_id': dishId,
        'quantity': quantity,
        'selected_options': serializableOptions,
      });

      await _loadCart();
    } catch (e) {
      print('Add to Cart Fehler: $e');
      throw e;
    }
  }

  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity < 1) return removeFromCart(cartItemId);

    try {
      await supabase
          .from('cart_items')
          .update({'quantity': newQuantity})
          .eq('id', cartItemId);

      await _loadCart();
    } catch (e) {
      print('Update Quantity Fehler: $e');
      throw e;
    }
  }

  Future<void> removeFromCart(String cartItemId) async {
    try {
      await supabase.from('cart_items').delete().eq('id', cartItemId);
      await _loadCart();
    } catch (e) {
      print('Remove from Cart Fehler: $e');
      throw e;
    }
  }

  Future<void> clearCart() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    try {
      await supabase.from('cart_items').delete().eq('user_id', user.id);
      state = const AsyncData([]);
    } catch (e) {
      print('Clear Cart Fehler: $e');
      throw e;
    }
  }
}