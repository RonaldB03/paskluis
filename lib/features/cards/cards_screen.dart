import 'package:flutter/material.dart';
import '../../shared/widgets/card_list_view.dart';

class CardsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Function(String id) onDelete;
  final Function(String id) onToggleFavorite;

  const CardsScreen({
    super.key,
    required this.items,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return CardListView(
      items: items,
      icon: Icons.credit_card,
      emptyTitle: 'Nog geen pasjes',
      emptySubtitle: 'Voeg klantenkaarten, ledenpassen of spaarkaarten toe.',
      onDelete: onDelete,
      onToggleFavorite: onToggleFavorite,
    );
  }
}