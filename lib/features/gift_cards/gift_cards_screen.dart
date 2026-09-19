import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/gift_card_share_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../../shared/widgets/main_tab_swipe_region.dart';
import '../../shared/widgets/premium_app_title.dart';
import '../../shared/widgets/main_tab_route.dart';

import '../cards/card_preview_screen.dart';
import '../cards/cards_screen.dart';
import '../cards/choose_card_template_screen.dart';

import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';
import '../premium/premium_gate.dart';

import 'choose_gift_card_template_screen.dart';
import 'gift_card_view_screen.dart';

class GiftCardsScreen extends StatelessWidget {
  const GiftCardsScreen({super.key});

  List<Map<String, dynamic>> getItems() {
    final items = StorageService.cardsBox.values
        .where((item) =>
            item is Map &&
            item['type'] == 'Cadeaukaart' &&
            item['isArchived'] != true &&
            item['isArchived']?.toString() != 'true')
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
      'customImage': result['customImage'] ?? '',
      'isFavorite': result['isFavorite'] == 'true',
      'createdAt': result['createdAt'] ?? now,
      'updatedAt': result['updatedAt'] ?? now,
      'lastUsedAt': result['lastUsedAt'] ?? '',
      'balanceHistory': result['balanceHistory'] ?? '[]',
      'expiryDate': result['expiryDate'] ?? '',
      'expiryNotificationsEnabled':
          result['expiryNotificationsEnabled'] == 'true',
      'isArchived': result['isArchived'] == 'true',
    };

    await StorageService.cardsBox.add(card);
    await NotificationService.syncGiftCard(card);
    return card;
  }

  Future<void> openAddGiftCard(BuildContext context) async {
    if (!await PremiumGate.canAddGiftCard(context)) return;
    if (!context.mounted) return;

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const ChooseGiftCardTemplateScreen()),
    );

    if (!context.mounted || result == null) return;

    await saveNewCard(result, forcedType: 'Cadeaukaart');
  }

  Future<void> openLoyaltyAddFlow(BuildContext context) async {
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

  Future<void> openQrAddFlow(BuildContext context) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseCardTemplateScreen(type: 'QR-code'),
      ),
    );

    if (!context.mounted || result == null) return;

    await saveNewCard(result, forcedType: 'QR-code');
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
        title: const Text('Definitief verwijderen?'),
        content: Text(
          'Weet je zeker dat je "$name" definitief wilt verwijderen? Dit kun je niet ongedaan maken.',
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
            child: const Text('Definitief verwijderen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await NotificationService.cancelGiftCard(item['id']?.toString() ?? '');
    try {
      await GiftCardShareService.revokeAllForCard(item['id']?.toString() ?? '');
    } catch (_) {}
    await StorageService.deleteCard(key);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name is verwijderd.')));
  }

  void showGiftCardOptions(BuildContext context, Map<String, dynamic> item) {
    if (item['isShared'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deze kaart is met jou gedeeld en kan alleen door de eigenaar worden beheerd.')),
      );
      return;
    }
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
                  title: 'Definitief verwijderen',
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
    Widget screen;

    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;

      case 1:
        screen = const CardsScreen();
        break;

      case 2:
        screen = const QrCodesScreen();
        break;

      case 3:
        return;

      default:
        return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      mainTabRoute(screen, forward: index > 3),
      (_) => false,
    );
  }

  void openHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      mainTabRoute(const HomeScreen(), forward: false),
      (_) => false,
    );
  }

  void openGiftCard(
    BuildContext context,
    List<Map<String, dynamic>> items,
    int index,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftCardViewScreen(items: items, initialIndex: index),
      ),
    );
  }

  Future<void> showArchivedCards(BuildContext context) async {
    final archived = StorageService.cardsBox.values
        .where((item) =>
            item is Map &&
            item['type'] == 'Cadeaukaart' &&
            (item['isArchived'] == true || item['isArchived']?.toString() == 'true'))
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Archief', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              if (archived.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Er staan nog geen cadeaukaarten in het archief.'),
                )
              else
                ...archived.map((item) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.card_giftcard_rounded)),
                      title: Text(item['name']?.toString() ?? 'Cadeaukaart'),
                      subtitle: Text(
                        'Saldo € ${formatAmountValue(item['currentBalance'] ?? '0')}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final key = findHiveKey(item);
                              if (key == null) return;
                              final restored = {...item, 'isArchived': false, 'archivedAt': ''};
                              await StorageService.saveCard(key, restored);
                              await NotificationService.syncGiftCard(restored);
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                            },
                            child: const Text('Terugzetten'),
                          ),
                          IconButton(
                            tooltip: 'Definitief verwijderen',
                            color: Colors.red,
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              await deleteGiftCard(context, item);
                            },
                            icon: const Icon(Icons.delete_forever_rounded),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
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
            title: const PremiumAppTitle('Cadeaukaarten'),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF333333),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Gedeelde kaarten vernieuwen',
                icon: const Icon(Icons.sync_rounded),
                onPressed: () async {
                  try {
                    await GiftCardShareService.syncIncomingToLocal();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gedeelde kaarten zijn bijgewerkt.')),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bijwerken lukte niet. Controleer of je bent ingelogd.')),
                      );
                    }
                  }
                },
              ),
              IconButton(
                tooltip: 'Archief',
                icon: const Icon(Icons.archive_outlined),
                onPressed: () => showArchivedCards(context),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFFD51B46), size: 32),
                onPressed: () => openAddGiftCard(context),
              ),
            ],
          ),
          body: MainTabSwipeRegion(
            currentIndex: 3,
            onSwitch: (index) => openTab(context, index),
            child: items.isEmpty
                ? _EmptyGiftCardState(onAdd: () => openAddGiftCard(context))
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
                        SettingsService.extraClearEnabled ? 2.35 : 1.42,
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
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 3,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
      ),
    );
  }
}

class _EmptyGiftCardState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyGiftCardState({required this.onAdd});

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
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
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

  bool get hasAssetLogo {
    return (widget.item['logoAsset']?.toString() ?? '').isNotEmpty;
  }

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
    final expiryDate = DateTime.tryParse(widget.item['expiryDate']?.toString() ?? '');
    final isExpired = expiryDate != null &&
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
            .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final hasLogo = hasAssetLogo || hasCustomLogo;
    final usesBrandBackground =
        hasLogo && (widget.item['brandColor']?.toString() ?? '').isNotEmpty;
    final hasDarkBrandBackground =
        usesBrandBackground && cardColor.computeLuminance() < 0.55;
    final normalizedBrand =
        '${widget.item['brandId']} $title $logoAsset'.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
    final logoScale = normalizedBrand.contains('albertheijn')
        ? 2.65
        : normalizedBrand.contains('gallgall')
        ? 2.15
        : 1.75;

    return Semantics(
      button: true,
      label:
          '$title, cadeaukaart, ${balance.isEmpty ? 'saldo onbekend' : 'saldo € ${formatAmountValue(balance)}'}${isFavorite ? ', favoriet' : ''}',
      hint: 'Tik tweemaal om de cadeaukaart te openen',
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
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
          decoration: BoxDecoration(
            color: usesBrandBackground ? cardColor : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isPressed ? 0.035 : 0.06),
                blurRadius: isPressed ? 8 : 12,
                offset: Offset(0, isPressed ? 3 : 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
              Expanded(
                child: ClipRect(
                  child: Center(
                    child: hasLogo
                        ? hasCustomLogo
                            ? Transform.scale(
                                scale: 1.5,
                                child: Image.file(
                                  File(customImage),
                                  fit: BoxFit.contain,
                                  height: 96,
                                  width: double.infinity,
                                ),
                              )
                            : SizedBox(
                                height: 96,
                                width: double.infinity,
                                child: BrandLogo(
                                  source: logoAsset,
                                  scale: logoScale,
                                ),
                              )
                        : Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: usesBrandBackground
                                ? Colors.white
                                : const Color(0xFF333333),
                          ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: hasDarkBrandBackground
                      ? Colors.white.withOpacity(0.22)
                      : const Color(0xFFD51B46),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  balance.isEmpty
                      ? 'Saldo onbekend'
                      : '€ ${formatAmountValue(balance)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
                ],
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
              if (isExpired)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Verlopen',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
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
