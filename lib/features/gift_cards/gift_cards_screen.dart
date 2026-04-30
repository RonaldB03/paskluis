import 'package:flutter/material.dart';
import '../../shared/widgets/card_list_view.dart';

class GiftCardsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Function(String id) onDelete;
  final Function(String id) onToggleFavorite;

  const GiftCardsScreen({
    super.key,
    required this.items,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return CardListView(
      items: items,
      icon: Icons.card_giftcard,
      emptyTitle: 'Nog geen cadeaukaarten',
      emptySubtitle: 'Sla cadeaukaarten veilig op met saldo en beveiliging.',
      onDelete: onDelete,
      onToggleFavorite: onToggleFavorite,
    );
  }
}