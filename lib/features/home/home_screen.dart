import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../shared/widgets/main_bottom_nav.dart';

import '../cards/card_preview_screen.dart';
import '../cards/card_view_screen.dart';
import '../cards/cards_screen.dart';
import '../cards/choose_card_template_screen.dart';
import '../cards/edit_card_screen.dart';

import '../gift_cards/add_gift_card_screen.dart';
import '../gift_cards/choose_gift_card_template_screen.dart';
import '../gift_cards/gift_card_view_screen.dart';
import '../gift_cards/gift_cards_screen.dart';

import '../qr_codes/qr_codes_screen.dart';
import '../qr_codes/choose_qr_code_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> getItemsByType(String type) {
    return StorageService.cardsBox.values
        .where((item) => item is Map && item['type'] == type)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  List<Map<String, dynamic>> getPreviewItems(List<Map<String, dynamic>> items) {
    final sorted = [...items];

    sorted.sort((a, b) {
      final aFavorite = a['isFavorite'] == true;
      final bFavorite = b['isFavorite'] == true;

      if (aFavorite != bFavorite) return aFavorite ? -1 : 1;

      final aLastUsed = DateTime.tryParse(a['lastUsedAt']?.toString() ?? '');
      final bLastUsed = DateTime.tryParse(b['lastUsedAt']?.toString() ?? '');

      final aCreated = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bCreated = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final aDate = aLastUsed ?? aCreated;
      final bDate = bLastUsed ?? bCreated;

      return bDate.compareTo(aDate);
    });

    return sorted.take(3).toList();
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
    };

    await StorageService.cardsBox.add(card);
    return card;
  }

  Future<void> openLoyaltyAddFlow() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseCardTemplateScreen(type: 'Pasje'),
      ),
    );

    if (!mounted || result == null) return;

    final savedCard = await saveNewCard(result, forcedType: 'Pasje');

    if (!mounted) return;

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

  Future<void> openQrAddFlow() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseQrCodeScreen(),
      ),
    );

    if (!mounted || result == null) return;

    final now = DateTime.now().toIso8601String();
    final type = result['type'] ?? 'QR-code';

    if (type == 'QR-set') {
      final codes = result['codes'] ?? '';
      final codeList = codes
          .split('|||')
          .where((code) => code.trim().isNotEmpty)
          .toList();

      await StorageService.cardsBox.add({
        'id': result['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'QR-set',
        'name': result['name'] ?? 'QR-codes (${codeList.length})',
        'code': '',
        'codes': codes,
        'used': result['used'] ??
            List.filled(codeList.length, 'false').join('|||'),
        'note': result['note'] ?? '',
        'cardNumber': '',
        'pinCode': '',
        'initialBalance': '',
        'currentBalance': '',
        'brandId': '',
        'logoAsset': '',
        'brandColor': '',
        'customImage': '',
        'isFavorite': result['isFavorite'] == 'true',
        'createdAt': result['createdAt'] ?? now,
        'updatedAt': result['updatedAt'] ?? now,
        'lastUsedAt': result['lastUsedAt'] ?? '',
        'balanceHistory': '[]',
      });

      return;
    }

    await saveNewCard(result, forcedType: 'QR-code');
  }

  Future<void> openGiftCardAddFlow() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseGiftCardTemplateScreen(),
      ),
    );

    if (!mounted || result == null) return;

    await saveNewCard(result, forcedType: 'Cadeaukaart');
  }

  Future<void> editLoyaltyCard(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditCardScreen(item: item),
      ),
    );

    if (updated == null) return;

    final oldItem = Map<String, dynamic>.from(
      StorageService.cardsBox.get(key) as Map,
    );

    await StorageService.cardsBox.put(key, {
      ...oldItem,
      ...updated,
      'id': oldItem['id'],
      'type': 'Pasje',
      'createdAt': oldItem['createdAt'],
      'isFavorite': oldItem['isFavorite'] == true,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> editGiftCard(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final updated = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddGiftCardScreen(
          isEditing: true,
          initialName: item['name']?.toString() ?? '',
          initialCode: item['code']?.toString() ?? '',
          initialCardNumber: item['cardNumber']?.toString() ?? '',
          initialPinCode: item['pinCode']?.toString() ?? '',
          initialInitialBalance: item['initialBalance']?.toString() ?? '',
          initialCurrentBalance: item['currentBalance']?.toString() ?? '',
          initialNote: item['note']?.toString() ?? '',
          initialBrandId: item['brandId']?.toString() ?? '',
          initialLogoAsset: item['logoAsset']?.toString() ?? '',
          initialBrandColor: item['brandColor']?.toString() ?? '',
          initialCustomImage: item['customImage']?.toString() ?? '',
        ),
      ),
    );

    if (updated == null) return;

    final oldItem = Map<String, dynamic>.from(
      StorageService.cardsBox.get(key) as Map,
    );

    await StorageService.cardsBox.put(key, {
      ...oldItem,
      ...updated,
      'id': oldItem['id'],
      'type': 'Cadeaukaart',
      'createdAt': oldItem['createdAt'],
      'isFavorite': oldItem['isFavorite'] == true,
      'lastUsedAt': oldItem['lastUsedAt'] ?? '',
      'balanceHistory': oldItem['balanceHistory'] ?? '[]',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteItem(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final name = item['name']?.toString() ?? 'deze kaart';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verwijderen?'),
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
      SnackBar(content: Text('$name is verwijderd.')),
    );
  }

  void showItemOptions(
      BuildContext context,
      Map<String, dynamic> item,
      ) {
    final name = item['name']?.toString() ?? 'Kaart';
    final type = item['type']?.toString() ?? '';

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

                    if (type == 'Pasje') {
                      editLoyaltyCard(context, item);
                    } else if (type == 'Cadeaukaart') {
                      editGiftCard(context, item);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR-code bewerken maken we straks.'),
                        ),
                      );
                    }
                  },
                ),
                _OptionTile(
                  icon: Icons.delete_rounded,
                  title: 'Verwijderen',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    deleteItem(context, item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showAddChoices() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Wat wil je toevoegen?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _AddChoiceTile(
                  icon: Icons.card_membership,
                  title: 'Klantenkaart toevoegen',
                  onTap: () {
                    Navigator.pop(context);
                    openLoyaltyAddFlow();
                  },
                ),
                _AddChoiceTile(
                  icon: Icons.qr_code,
                  title: 'QR-code toevoegen',
                  onTap: () {
                    Navigator.pop(context);
                    openQrAddFlow();
                  },
                ),
                _AddChoiceTile(
                  icon: Icons.card_giftcard,
                  title: 'Cadeaukaart toevoegen',
                  onTap: () {
                    Navigator.pop(context);
                    openGiftCardAddFlow();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openTab(int index) {
    if (index == 0) return;

    Widget screen;

    if (index == 1) {
      screen = const CardsScreen();
    } else if (index == 2) {
      screen = const QrCodesScreen();
    } else {
      screen = const GiftCardsScreen();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void openCardView(
      List<Map<String, dynamic>> categoryItems,
      Map<String, dynamic> selectedItem,
      ) {
    final selectedId = selectedItem['id']?.toString() ?? '';

    final initialIndex = categoryItems.indexWhere(
          (item) => item['id']?.toString() == selectedId,
    );

    final type = selectedItem['type']?.toString() ?? '';

    if (type == 'Cadeaukaart') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GiftCardViewScreen(
            items: categoryItems,
            initialIndex: initialIndex < 0 ? 0 : initialIndex,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardViewScreen(
          items: categoryItems,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final cards = getItemsByType('Pasje');
        final qrCodes = StorageService.cardsBox.values
            .where((item) =>
        item is Map &&
            (item['type'] == 'QR-code' || item['type'] == 'QR-set'))
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        final giftCards = getItemsByType('Cadeaukaart');

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F6),
          appBar: AppBar(
            title: const Text('PasKluis'),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: const Color(0xFF333333),
            actions: [
              IconButton(
                onPressed: showAddChoices,
                icon: const Icon(
                  Icons.add,
                  color: Color(0xFFD51B46),
                  size: 32,
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              _CategorySection(
                title: 'Klantenkaarten',
                icon: Icons.card_membership,
                items: getPreviewItems(cards),
                hasItems: cards.isNotEmpty,
                actionTitle: cards.isEmpty ? 'Voeg kaart toe' : 'Al je kaarten',
                onActionTap:
                cards.isEmpty ? openLoyaltyAddFlow : () => openTab(1),
                onItemTap: (item) => openCardView(cards, item),
                onItemLongPress: (item) => showItemOptions(context, item),
              ),
              const SizedBox(height: 28),
              _CategorySection(
                title: 'QR-codes',
                icon: Icons.qr_code,
                items: getPreviewItems(qrCodes),
                hasItems: qrCodes.isNotEmpty,
                actionTitle:
                qrCodes.isEmpty ? 'Voeg QR-code toe' : 'Al je QR-codes',
                onActionTap: qrCodes.isEmpty ? openQrAddFlow : () => openTab(2),
                onItemTap: (item) => openCardView(qrCodes, item),
                onItemLongPress: (item) => showItemOptions(context, item),
              ),
              const SizedBox(height: 28),
              _CategorySection(
                title: 'Cadeaukaarten',
                icon: Icons.card_giftcard,
                items: getPreviewItems(giftCards),
                hasItems: giftCards.isNotEmpty,
                actionTitle: giftCards.isEmpty
                    ? 'Voeg cadeaukaart toe'
                    : 'Al je cadeaukaarten',
                onActionTap:
                giftCards.isEmpty ? openGiftCardAddFlow : () => openTab(3),
                onItemTap: (item) => openCardView(giftCards, item),
                onItemLongPress: (item) => showItemOptions(context, item),
              ),
            ],
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 0,
            onTap: openTab,
          ),
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final bool hasItems;
  final String actionTitle;
  final VoidCallback onActionTap;
  final Function(Map<String, dynamic> item) onItemTap;
  final Function(Map<String, dynamic> item) onItemLongPress;

  const _CategorySection({
    required this.title,
    required this.icon,
    required this.items,
    required this.hasItems,
    required this.actionTitle,
    required this.onActionTap,
    required this.onItemTap,
    required this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFD51B46)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return _ActionCard(
                title: actionTitle,
                icon: hasItems ? Icons.apps : Icons.add,
                onTap: onActionTap,
              );
            }

            final item = items[index];

            return _PreviewCard(
              title: item['name']?.toString() ?? 'Kaart',
              logoAsset: item['logoAsset']?.toString() ?? '',
              customImage: item['customImage']?.toString() ?? '',
              brandColor: item['brandColor']?.toString() ?? '',
              balance: item['currentBalance']?.toString() ?? '',
              type: item['type']?.toString() ?? '',
              onTap: () => onItemTap(item),
              onLongPress: () => onItemLongPress(item),
            );
          },
        ),
      ],
    );
  }
}

class _PreviewCard extends StatefulWidget {
  final String title;
  final String logoAsset;
  final String customImage;
  final String brandColor;
  final String balance;
  final String type;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PreviewCard({
    required this.title,
    required this.logoAsset,
    required this.customImage,
    required this.brandColor,
    required this.balance,
    required this.type,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<_PreviewCard> {
  bool isPressed = false;

  Color get cardColor {
    final parsed = int.tryParse(widget.brandColor);
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  bool get hasAssetLogo => widget.logoAsset.isNotEmpty;

  bool get hasCustomLogo =>
      widget.customImage.isNotEmpty && File(widget.customImage).existsSync();

  bool get isGiftCard => widget.type == 'Cadeaukaart';

  void setPressed(bool value) {
    if (!mounted) return;
    setState(() => isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(14),
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
              Expanded(
                child: useImage
                    ? Center(
                  child: hasCustomLogo
                      ? Image.file(
                    File(widget.customImage),
                    fit: BoxFit.contain,
                    height: 72,
                    width: double.infinity,
                  )
                      : Image.asset(
                    widget.logoAsset,
                    fit: BoxFit.contain,
                    height: 72,
                    width: double.infinity,
                  ),
                )
                    : Center(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: hasAssetLogo
                          ? Colors.white
                          : const Color(0xFF333333),
                    ),
                  ),
                ),
              ),
              if (isGiftCard) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: hasAssetLogo
                        ? Colors.white.withOpacity(0.18)
                        : const Color(0xFFF8E3EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.balance.isEmpty
                        ? 'Saldo onbekend'
                        : '€ ${widget.balance}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color:
                      hasAssetLogo ? Colors.white : const Color(0xFFD51B46),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFD51B46),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AddChoiceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF8E3EA),
        child: Icon(icon, color: const Color(0xFFD51B46)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.chevron_right),
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