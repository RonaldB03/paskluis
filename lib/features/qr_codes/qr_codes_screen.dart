import 'package:flutter/material.dart';
import '../../shared/widgets/card_list_view.dart';

class QrCodesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Function(String id) onDelete;
  final Function(String id) onToggleFavorite;

  const QrCodesScreen({
    super.key,
    required this.items,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return CardListView(
      items: items,
      icon: Icons.qr_code_2,
      emptyTitle: 'Nog geen QR-codes',
      emptySubtitle: 'Bewaar losse QR-codes zodat je ze snel bij de hand hebt.',
      onDelete: onDelete,
      onToggleFavorite: onToggleFavorite,
    );
  }
}