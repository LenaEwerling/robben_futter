import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cart_provider.dart';

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

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text('Gericht ID: ${item.dishId}'),
                subtitle: Text('Menge: ${item.quantity}'),
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
            // TODO: Bestell-Logik für alle Items
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