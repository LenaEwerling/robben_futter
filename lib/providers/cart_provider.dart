import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'auth_providers.dart' hide supabase;

class CartItem {
  final String id;
  final String dishId;
  final int quantity;
  final Map<String, dynamic> selectedOptions;
  final DateTime createdAt;

  CartItem({
    required this.id,
    required this.dishId,
    required this.quantity,
    required this.selectedOptions,
    required this.createdAt,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      dishId: json['dish_id'],
      quantity: json['quantity'],
      selectedOptions: json['selected_options'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
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
          .select()
          .eq('user_id', user.id)
          .order('created_at');

      final items = response.map((json) => CartItem.fromJson(json)).toList();
      state = AsyncData(items);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addToCart(String dishId, int quantity, Map<String, dynamic> selectedOptions) async {
    try {
      final user = ref.read(authNotifierProvider).value;
      if (user == null) throw Exception('Nicht eingeloggt');

      await supabase.from('cart_items').insert({
        'user_id': user.id,
        'dish_id': dishId,
        'quantity': quantity,
        'selected_options': selectedOptions,
      });

      await _loadCart(); // Refresh
    } catch (e) {
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
      throw e;
    }
  }

  Future<void> removeFromCart(String cartItemId) async {
    try {
      await supabase.from('cart_items').delete().eq('id', cartItemId);
      await _loadCart();
    } catch (e) {
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
      throw e;
    }
  }
}
