import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/card_share_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/utils/logo_layout.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../../shared/widgets/main_tab_swipe_region.dart';
import '../../shared/widgets/premium_app_title.dart';
import '../../shared/widgets/main_tab_route.dart';
import '../../shared/widgets/luxury_empty_state.dart';

import '../gift_cards/gift_cards_screen.dart';
import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';

import 'card_preview_screen.dart';
import 'card_view_screen.dart';
import 'choose_card_template_screen.dart';
import 'edit_card_screen.dart';

class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  List<Map<String, dynamic>> getItems() {
    final items = StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == 'Pasje')
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    items.sort((a, b) {
      final aFavorite = a['isFavorite'] == true;
      final bFavorite = b['isFavorite'] == true;

      if (aFavorite != bFavorite) return aFavorite ? -1 : 1;

      final aDate =
          DateTime.tryParse(a['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate =
          DateTime.tryParse(b['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<Map<String, dynamic>> saveNewCard(
    Map<String, String> result, {
    required String forcedType,
  }) async {
    final now = DateTime.now().toIso8601String();

    final Map<String, dynamic> card = {
      'id': result['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': result['type'] ?? forcedType,
      'name': result['name'] ?? '',
      'code': result['code'] ?? '',
      'codeFormat': result['codeFormat'] ?? 'barcode',
      'note': result['note'] ?? '',
      'cardNumber': result['cardNumber'] ?? '',
      'pinCode': result['pinCode'] ?? '',
      'initialBalance': result['initialBalance'] ?? '',
      'currentBalance': result['currentBalance'] ?? '',
      'brandId': result['brandId'] ?? '',
      'logoAsset': result['logoAsset'] ?? '',
      'brandColor': result['brandColor'] ?? '',
      for (final entry in result.entries)
        if (entry.key.startsWith('logo') &&
            (entry.key.endsWith('Scale') ||
                entry.key.endsWith('X') ||
                entry.key.endsWith('Y')))
          entry.key: entry.value,
      'customImage': result['customImage'] ?? '',
      'isFavorite': result['isFavorite'] == 'true',
      'createdAt': result['createdAt'] ?? now,
      'updatedAt': result['updatedAt'] ?? now,
      'lastUsedAt': result['lastUsedAt'] ?? '',
      'balanceHistory': result['balanceHistory'] ?? '[]',
    };

    await StorageService.cardsBox.add(card);
    return card;
  }

  Future<void> openAddCard(BuildContext context) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseCardTemplateScreen(type: 'Pasje'),
      ),
    );

    if (!context.mounted || result == null) return;

    final savedCard = await saveNewCard(result, forcedType: 'Pasje');

    if (!context.mounted) return;

    if (result['openPreviewAfterSave'] == 'true') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardPreviewScreen(
            item: savedCard.map(
              (key, value) => MapEntry(key, value?.toString() ?? ''),
            ),
          ),
        ),
      );
    }
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
    Widget screen;

    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        return;
      case 2:
        screen = const QrCodesScreen();
        break;
      case 3:
        screen = const GiftCardsScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      mainTabRoute(screen, forward: index > 1),
      (_) => false,
    );
  }

  void openHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      mainTabRoute(const HomeScreen(), forward: false),
      (_) => false,
    );
  }

  void openCard(
    BuildContext context,
    List<Map<String, dynamic>> items,
    int index,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardViewScreen(items: items, initialIndex: index),
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

    var savedCard = Map<String, dynamic>.from(newCard);
    if (savedCard['isShared'] == true ||
        (savedCard['sharedCardId']?.toString() ?? '').isNotEmpty) {
      savedCard = await CardShareService.updateSharedCard(savedCard);
    }

    await StorageService.saveCard(key, savedCard);
  }

  Future<void> deleteCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final name = item['name']?.toString() ?? 'deze kaart';
    final isShared = item['isShared'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isShared ? 'Uit jouw PasKluis verwijderen?' : 'Kaart verwijderen?',
        ),
        content: Text(
          isShared
              ? 'Je verwijdert "$name" alleen uit jouw PasKluis. De kaart van de eigenaar blijft bestaan.'
              : 'Weet je zeker dat je "$name" wilt verwijderen? Gedeelde toegang wordt voor iedereen gestopt.',
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

    try {
      if (isShared) {
        await CardShareService.removeReceivedCard(
          item['shareMembershipId']?.toString() ?? '',
        );
      } else if ((item['sharedCardId']?.toString() ?? '').isNotEmpty) {
        await CardShareService.revokeAllForCard(
          item['id']?.toString() ?? '',
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'De gedeelde toegang kon niet worden bijgewerkt. Probeer het opnieuw met internetverbinding.',
            ),
          ),
        );
      }
      return;
    }
    await StorageService.deleteCard(key);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name is verwijderd.')));
  }

  void showCardOptions(BuildContext context, Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Kaart';
    final isShared = item['isShared'] == true;
    final canEdit = !isShared || item['canEditShared'] == true;

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
                if (canEdit)
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
                  title: isShared
                      ? 'Uit mijn PasKluis verwijderen'
                      : 'Verwijderen',
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) openHome(context);
      },
      child: ValueListenableBuilder<Box>(
      valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final items = getItems();

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F6),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const PremiumAppTitle('Klantenkaarten'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFFD51B46), size: 32),
                onPressed: () => openAddCard(context),
              ),
            ],
          ),
          body: MainTabSwipeRegion(
            currentIndex: 1,
            onSwitch: (index) => openTab(context, index),
            child: items.isEmpty
                ? _EmptyCardsState(onAdd: () => openAddCard(context))
                : GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: SettingsService.extraClearEnabled ? 1 : 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio:
                        SettingsService.extraClearEnabled ? 2.65 : 1.58,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return StoredCardTile(
                      item: item,
                      onTap: () => openCard(context, items, index),
                      onLongPress: () => showCardOptions(context, item),
                    );
                  },
                  ),
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 1,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
      ),
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCardsState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return LuxuryEmptyState(
      icon: Icons.card_membership_rounded,
      eyebrow: 'Alles bij de hand',
      title: 'Voeg je eerste klantenkaart toe',
      subtitle:
          'Kies een winkel, scan de barcode of importeer een foto. PasKluis bewaart je kaart veilig op dit toestel.',
      buttonLabel: 'Klantenkaart toevoegen',
      onPressed: onAdd,
      footer: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 17, color: Color(0xFF77717D)),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Geen account nodig',
              style: TextStyle(color: Color(0xFF77717D)),
            ),
          ),
        ],
      ),
    );
  }
}

class StoredCardTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const StoredCardTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<StoredCardTile> createState() => _StoredCardTileState();
}

class _StoredCardTileState extends State<StoredCardTile> {
  bool isPressed = false;

  Color get cardColor {
    final parsed = int.tryParse(widget.item['brandColor']?.toString() ?? '');
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  bool get hasAssetLogo {
    return (widget.item['logoAsset']?.toString() ?? '').isNotEmpty;
  }

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
    final usesBrandBackground =
        useImage && (widget.item['brandColor']?.toString() ?? '').isNotEmpty;
    final hasDarkBrandBackground =
        usesBrandBackground && cardColor.computeLuminance() < 0.55;

    return Semantics(
      button: true,
      label: '$title, klantenkaart${isFavorite ? ', favoriet' : ''}',
      hint: 'Tik tweemaal om de kaart te openen',
      child: GestureDetector(
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: usesBrandBackground ? cardColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isPressed ? 0.035 : 0.06),
                blurRadius: isPressed ? 8 : 12,
                offset: Offset(0, isPressed ? 3 : 5),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: Center(
                  child: useImage
                      ? Transform.scale(
                          scale: hasCustomLogo ? 1.55 : 1.0,
                          child: hasCustomLogo
                              ? Image.file(
                                  File(customImage),
                                  fit: BoxFit.contain,
                                  height: 92,
                                  width: double.infinity,
                                )
                              : SizedBox(
                                  height: 92,
                                  width: double.infinity,
                                  child: BrandLogo(
                                    source: logoAsset,
                                    scale: logoLayoutValue(
                                      widget.item,
                                      'loyalty',
                                      'scale',
                                      1,
                                    ),
                                    offsetX: logoLayoutValue(
                                      widget.item,
                                      'loyalty',
                                      'x',
                                      0,
                                    ),
                                    offsetY: logoLayoutValue(
                                      widget.item,
                                      'loyalty',
                                      'y',
                                      0,
                                    ),
                                  ),
                                ),
                        )
                      : Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: usesBrandBackground
                                ? Colors.white
                                : const Color(0xFF333333),
                          ),
                        ),
                ),
              ),
              if (isFavorite)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.star,
                    color: hasDarkBrandBackground
                        ? Colors.white
                        : const Color(0xFFD51B46),
                    size: 24,
                  ),
                ),
            ],
          ),
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
