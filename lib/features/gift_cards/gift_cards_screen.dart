import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../cards/cards_screen.dart';
import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';
import 'choose_gift_card_template_screen.dart';
import 'gift_card_view_screen.dart';

class GiftCardsScreen extends StatelessWidget {
  final VoidCallback onAdd;

  const GiftCardsScreen({
    super.key,
    required this.onAdd,
  });

  List<Map<String, dynamic>> getItems() {
    final items = StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == 'Cadeaukaart')
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

  Future<void> openAddGiftCard(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseGiftCardTemplateScreen(),
      ),
    );
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

  Future<void> deleteGiftCard(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final name = item['name']?.toString() ?? 'deze cadeaukaart';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cadeaukaart verwijderen?'),
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

  void showGiftCardOptions(BuildContext context, Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Cadeaukaart';

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
                  icon: Icons.delete_rounded,
                  title: 'Verwijderen',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    deleteGiftCard(context, item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openTab(BuildContext context, int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CardsScreen(onAdd: () {})),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QrCodesScreen(onAdd: () {})),
      );
    } else if (index == 3) {
      return;
    }
  }

  void openGiftCard(
      BuildContext context,
      List<Map<String, dynamic>> items,
      int index,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftCardViewScreen(
          items: items,
          initialIndex: index,
        ),
      ),
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
            title: const Text(
              'Cadeaukaarten',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF333333),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.add,
                  color: Color(0xFFD51B46),
                  size: 32,
                ),
                onPressed: () => openAddGiftCard(context),
              ),
            ],
          ),
          body: items.isEmpty
              ? _EmptyGiftCardState(
            onAdd: () => openAddGiftCard(context),
          )
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
              childAspectRatio: 1.28,
            ),
            itemBuilder: (context, index) {
              final item = items[index];

              return _GiftCardTile(
                item: item,
                onTap: () => openGiftCard(context, items, index),
                onLongPress: () => showGiftCardOptions(context, item),
              );
            },
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 3,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
    );
  }
}

class _EmptyGiftCardState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyGiftCardState({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFFF8E3EA),
              child: Icon(
                Icons.card_giftcard,
                size: 48,
                color: Color(0xFFD51B46),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Nog geen cadeaukaarten toegevoegd',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bewaar cadeaukaarten met barcode, saldo en pincode of krascode.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: Color(0xFF555557),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Cadeaukaart toevoegen'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD51B46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftCardTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GiftCardTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_GiftCardTile> createState() => _GiftCardTileState();
}

class _GiftCardTileState extends State<_GiftCardTile> {
  bool isPressed = false;

  bool get hasCustomLogo {
    final path = widget.item['customImage']?.toString() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  bool get hasAssetLogo =>
      (widget.item['logoAsset']?.toString() ?? '').isNotEmpty;

  Color get cardColor {
    final parsed = int.tryParse(widget.item['brandColor']?.toString() ?? '');
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  void setPressed(bool value) {
    if (!mounted) return;
    setState(() => isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item['name']?.toString() ?? 'Cadeaukaart';
    final logoAsset = widget.item['logoAsset']?.toString() ?? '';
    final customImage = widget.item['customImage']?.toString() ?? '';
    final balance = widget.item['currentBalance']?.toString() ?? '';
    final isFavorite = widget.item['isFavorite'] == true;
    final hasLogo = hasAssetLogo || hasCustomLogo;

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
            borderRadius: BorderRadius.circular(22),
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
                  isFavorite ? Icons.star : Icons.card_giftcard,
                  color: hasAssetLogo ? Colors.white : const Color(0xFFD51B46),
                  size: 22,
                ),
              ),
              Expanded(
                child: Center(
                  child: hasLogo
                      ? hasCustomLogo
                      ? Image.file(
                    File(customImage),
                    fit: BoxFit.contain,
                    height: 66,
                    width: double.infinity,
                  )
                      : Image.asset(
                    logoAsset,
                    fit: BoxFit.contain,
                    height: 66,
                    width: double.infinity,
                  )
                      : Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: hasAssetLogo
                          ? Colors.white
                          : const Color(0xFF333333),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: hasAssetLogo
                      ? Colors.white.withOpacity(0.18)
                      : const Color(0xFFF8E3EA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  balance.isEmpty ? 'Saldo onbekend' : '€ $balance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color:
                    hasAssetLogo ? Colors.white : const Color(0xFFD51B46),
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