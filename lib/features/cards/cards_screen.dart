import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../data/templates/card_templates.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';
import 'card_view_screen.dart';
import 'edit_card_screen.dart';

class CardsScreen extends StatelessWidget {
  final VoidCallback onAdd;

  const CardsScreen({
    super.key,
    required this.onAdd,
  });

  List<Map<String, dynamic>> getItems() {
    final items = StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == 'Pasje')
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    items.sort((a, b) {
      final aFavorite = a['isFavorite'] == true;
      final bFavorite = b['isFavorite'] == true;

      if (aFavorite != bFavorite) return aFavorite ? -1 : 1;

      final aDate = DateTime.tryParse(a['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate = DateTime.tryParse(b['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return items;
  }

  dynamic findHiveKey(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';

    for (final key in StorageService.cardsBox.keys) {
      final value = StorageService.cardsBox.get(key);

      if (value is Map && value['id']?.toString() == id) {
        return key;
      }
    }

    return null;
  }

  void openTab(BuildContext context, int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );
    } else if (index == 1) {
      return;
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QrCodesScreen(onAdd: () {})),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GiftCardsScreen(onAdd: () {})),
      );
    }
  }

  void openCard(
      BuildContext context,
      List<Map<String, dynamic>> items,
      int index,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardViewScreen(
          items: items,
          initialIndex: index,
        ),
      ),
    );
  }

  Future<void> editCard(BuildContext context, Map<String, dynamic> item) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditCardScreen(
          item: item.map(
                (key, value) => MapEntry(key, value?.toString() ?? ''),
          ),
        ),
      ),
    );

    if (updated == null) return;

    final oldCard = Map<String, dynamic>.from(
      StorageService.cardsBox.get(key) as Map,
    );

    final newCard = {
      ...oldCard,
      ...updated,
      'isFavorite': oldCard['isFavorite'] == true,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await StorageService.cardsBox.put(key, newCard);
  }

  Future<void> deleteCard(BuildContext context, Map<String, dynamic> item) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final name = item['name']?.toString() ?? 'deze kaart';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kaart verwijderen?'),
        content: Text(
          'Weet je zeker dat je "$name" wilt verwijderen? Dit kun je niet ongedaan maken.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD51B46),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await StorageService.cardsBox.delete(key);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name is verwijderd.'),
      ),
    );
  }

  void showCardOptions(BuildContext context, Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Kaart';

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                _OptionTile(
                  icon: Icons.edit_rounded,
                  title: 'Bewerken',
                  onTap: () {
                    Navigator.pop(context);
                    editCard(context, item);
                  },
                ),
                _OptionTile(
                  icon: Icons.delete_rounded,
                  title: 'Verwijderen',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    deleteCard(context, item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final items = getItems();

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F6),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(
                Icons.home_rounded,
                color: Color(0xFFD51B46),
              ),
              onPressed: () => openTab(context, 0),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Klantenkaarten',
              style: TextStyle(
                color: Color(0xFF333333),
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.add,
                  color: Color(0xFFD51B46),
                  size: 32,
                ),
                onPressed: onAdd,
              ),
            ],
          ),
          body: items.isEmpty
              ? _EmptyCardsState(onAdd: onAdd)
              : GridView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.45,
            ),
            itemBuilder: (context, index) {
              final item = items[index];

              return _StoredCardTile(
                item: item,
                onTap: () => openCard(context, items, index),
                onLongPress: () => showCardOptions(context, item),
              );
            },
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 1,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCardsState({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final previewBrands = cardBrandTemplates.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
      children: [
        const Text(
          'Nog geen klantenkaarten toegevoegd',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            height: 1.12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF444446),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tik op + of kies een populaire winkel om je klantenkaart toe te voegen.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            height: 1.3,
            color: Color(0xFF555557),
          ),
        ),
        const SizedBox(height: 30),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Klantenkaart toevoegen'),
        ),
        const SizedBox(height: 34),
        const Text(
          'Populaire winkels',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: previewBrands.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            final brand = previewBrands[index];

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: brand.color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Image.asset(
                    brand.logoAsset,
                    fit: BoxFit.contain,
                    height: 74,
                    width: double.infinity,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StoredCardTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _StoredCardTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_StoredCardTile> createState() => _StoredCardTileState();
}

class _StoredCardTileState extends State<_StoredCardTile> {
  bool isPressed = false;

  Color get cardColor {
    final parsed = int.tryParse(widget.item['brandColor']?.toString() ?? '');
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  bool get hasAssetLogo =>
      (widget.item['logoAsset']?.toString() ?? '').isNotEmpty;

  bool get hasCustomLogo {
    final path = widget.item['customImage']?.toString() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  void setPressed(bool value) {
    if (!mounted) return;
    setState(() => isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final logoAsset = widget.item['logoAsset']?.toString() ?? '';
    final customImage = widget.item['customImage']?.toString() ?? '';
    final title = widget.item['name']?.toString() ?? 'Kaart';
    final isFavorite = widget.item['isFavorite'] == true;
    final useImage = hasAssetLogo || hasCustomLogo;

    return GestureDetector(
      onTapDown: (_) => setPressed(true),
      onTapCancel: () => setPressed(false),
      onTapUp: (_) => setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: hasAssetLogo ? cardColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isPressed ? 0.035 : 0.06),
                blurRadius: isPressed ? 8 : 12,
                offset: Offset(0, isPressed ? 3 : 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Icon(
                  isFavorite ? Icons.star : Icons.card_membership,
                  color: hasAssetLogo ? Colors.white : const Color(0xFFD51B46),
                  size: 22,
                ),
              ),
              Expanded(
                child: Center(
                  child: useImage
                      ? hasCustomLogo
                      ? Image.file(
                    File(customImage),
                    fit: BoxFit.contain,
                    height: 74,
                    width: double.infinity,
                  )
                      : Image.asset(
                    logoAsset,
                    fit: BoxFit.contain,
                    height: 74,
                    width: double.infinity,
                  )
                      : Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: hasAssetLogo
                          ? Colors.white
                          : const Color(0xFF333333),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : const Color(0xFFD51B46);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : const Color(0xFF333333),
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}