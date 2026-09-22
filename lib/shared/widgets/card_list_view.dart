import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../features/cards/card_detail_screen.dart';
import 'empty_state_card.dart';

class CardListView extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final IconData icon;
  final String emptyTitle;
  final String emptySubtitle;
  final Function(String id) onDelete;
  final Function(String id) onToggleFavorite;

  const CardListView({
    super.key,
    required this.items,
    required this.icon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  State<CardListView> createState() => _CardListViewState();
}

class _CardListViewState extends State<CardListView> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    final filteredItems = widget.items.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final code = item['code']?.toString().toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();

      return name.contains(query) || code.contains(query);
    }).toList();

    filteredItems.sort((a, b) {
      final aFav = a['isFavorite'] == true;
      final bFav = b['isFavorite'] == true;

      if (aFav == bFav) return 0;
      return aFav ? -1 : 1;
    });

    if (widget.items.isEmpty) {
      return EmptyStateCard(
        icon: widget.icon,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: L10n.current.searching,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
            ),
            onChanged: (value) {
              setState(() => searchQuery = value);
            },
          ),
        ),
        if (filteredItems.isEmpty)
           Expanded(child: Center(child: Text(L10n.current.noResultsFound)))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final isFavorite = item['isFavorite'] == true;

                return Card(
                  child: ListTile(
                    leading: Icon(widget.icon),
                    title: Text(item['name']?.toString() ?? ''),
                    subtitle: Text(item['code']?.toString() ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                          ),
                          onPressed: () => widget.onToggleFavorite(
                            item['id']?.toString() ?? '',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title:  Text(L10n.current.delete468),
                                  content: Text(
                                    L10n.current.areYouSureYouWantToDelete743((item['name']).toString()),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child:  Text(L10n.current.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child:  Text(L10n.current.delete),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmed == true) {
                              widget.onDelete(item['id']?.toString() ?? '');
                            }
                          },
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardDetailScreen(
                            item: Map<String, String>.from(
                              item.map(
                                (key, value) => MapEntry(key, value.toString()),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
