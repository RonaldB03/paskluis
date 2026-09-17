import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../data/services/image_color_service.dart';
import '../../data/services/smart_card_import_service.dart';
import '../../data/services/brand_sync_service.dart';
import '../../data/services/media_storage_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../../shared/widgets/main_tab_swipe_region.dart';
import '../../shared/widgets/premium_app_title.dart';

import '../cards/card_preview_screen.dart';
import '../cards/card_view_screen.dart';
import '../cards/cards_screen.dart';
import '../cards/choose_card_template_screen.dart';
import '../cards/add_card_screen.dart';
import '../cards/edit_card_screen.dart';

import '../gift_cards/add_gift_card_screen.dart';
import '../gift_cards/choose_gift_card_template_screen.dart';
import '../gift_cards/gift_card_view_screen.dart';
import '../gift_cards/gift_cards_screen.dart';

import '../qr_codes/qr_codes_screen.dart';
import '../qr_codes/add_qr_code_screen.dart';
import '../qr_codes/choose_qr_code_screen.dart';
import '../settings/settings_screen.dart';
import '../premium/premium_gate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshVisualAssets();
  }

  Future<void> _refreshVisualAssets() async {
    await _repairMovedCustomImages();
    await BrandSyncService.refreshSavedCards();
    await _repairMissingCustomLogoColors();
  }

  Future<void> _repairMovedCustomImages() async {
    for (final key in StorageService.cardsBox.keys.toList()) {
      final raw = StorageService.cardsBox.get(key);
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final storedPath = item['customImage']?.toString() ?? '';
      if (storedPath.isEmpty) continue;
      final resolved = await MediaStorageService.resolveManagedImage(storedPath);
      if (resolved == null || resolved == storedPath) continue;
      item['customImage'] = resolved;
      item['updatedAt'] = DateTime.now().toIso8601String();
      await StorageService.saveCard(key, item);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _repairMissingCustomLogoColors() async {
    for (final key in StorageService.cardsBox.keys.toList()) {
      final raw = StorageService.cardsBox.get(key);
      if (raw is! Map) continue;

      final item = Map<String, dynamic>.from(raw);
      final path = item['customImage']?.toString() ?? '';
      final color = item['brandColor']?.toString() ?? '';
      if (path.isEmpty || color.isNotEmpty || !File(path).existsSync()) continue;

      final detected = await ImageColorService.dominantEdgeColor(path);
      if (detected == null) continue;

      item['brandColor'] = detected.value.toString();
      item['updatedAt'] = DateTime.now().toIso8601String();
      await StorageService.saveCard(key, item);
    }
  }
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

      final aCreated =
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bCreated =
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
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
      MaterialPageRoute(builder: (_) => const ChooseQrCodeScreen()),
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
        'used':
            result['used'] ?? List.filled(codeList.length, 'false').join('|||'),
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
    if (!await PremiumGate.canAddGiftCard(context)) return;
    if (!mounted) return;

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const ChooseGiftCardTemplateScreen()),
    );

    if (!mounted || result == null) return;

    await saveNewCard(result, forcedType: 'Cadeaukaart');
  }

  Future<void> openSmartImport() async {
    Navigator.pop(context);
    final result = await SmartCardImportService.pickAndAnalyze();
    if (!mounted || result == null) return;

    final type = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.auto_awesome_rounded,
          color: Color(0xFFD51B46),
          size: 38,
        ),
        title: Text(
          result.brand == null
              ? 'Kaart herkend'
              : '${result.brand!.name} herkend',
        ),
        content: Text(
          'PasKluis denkt dat dit een ${result.type.toLowerCase()} is. Kies het juiste type om de gegevens te controleren.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'Pasje'),
            child: const Text('Klantenkaart'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'QR-code'),
            child: const Text('QR-code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'Cadeaukaart'),
            child: const Text('Cadeaukaart'),
          ),
        ],
      ),
    );
    if (!mounted || type == null) return;

    final brand = result.brand;
    Map<String, String>? saved;
    if (type == 'Cadeaukaart') {
      if (!await PremiumGate.canAddGiftCard(context) || !mounted) return;
      saved = await Navigator.push<Map<String, String>>(
        context,
        MaterialPageRoute(
          builder: (_) => AddGiftCardScreen(
            initialName: result.name,
            initialCode: result.code,
            initialPinCode: result.pinCode,
            initialCurrentBalance: result.balance,
            initialBrandId: brand?.id,
            initialLogoAsset: brand?.logoAsset,
            initialBrandColor: brand?.color.value.toString(),
          ),
        ),
      );
    } else if (type == 'QR-code') {
      saved = await Navigator.push<Map<String, String>>(
        context,
        MaterialPageRoute(
          builder: (_) => AddQrCodeScreen(
            initialName: result.name,
            initialCode: result.code,
            initialBrandId: brand?.id,
            initialLogoAsset: brand?.logoAsset,
            initialBrandColor: brand?.color.value.toString(),
          ),
        ),
      );
    } else {
      saved = await Navigator.push<Map<String, String>>(
        context,
        MaterialPageRoute(
          builder: (_) => AddCardScreen(
            initialType: 'Pasje',
            initialName: result.name,
            initialCode: result.code,
            initialBrandId: brand?.id,
            initialLogoAsset: brand?.logoAsset,
            initialBrandColor: brand?.color.value.toString(),
          ),
        ),
      );
    }

    if (!mounted || saved == null) return;
    await saveNewCard(saved, forcedType: type);
  }

  Future<void> editLoyaltyCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditCardScreen(item: item)),
    );

    if (updated == null) return;

    final oldItem = Map<String, dynamic>.from(
      StorageService.cardsBox.get(key) as Map,
    );

    await StorageService.saveCard(key, {
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

    await StorageService.saveCard(key, {
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

    await StorageService.deleteCard(key);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name is verwijderd.')));
  }

  void showItemOptions(BuildContext context, Map<String, dynamic> item) {
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
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                _AddChoiceTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Slim importeren uit foto',
                  onTap: openSmartImport,
                ),
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

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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

    if (type == 'QR-code' || type == 'QR-set') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrCodeViewScreen(
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
            .where(
              (item) =>
                  item is Map &&
                  (item['type'] == 'QR-code' || item['type'] == 'QR-set'),
            )
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        final giftCards = getItemsByType('Cadeaukaart');
        final allItems = [...cards, ...qrCodes, ...giftCards];
        final favorites = allItems
            .where((item) => item['isFavorite'] == true)
            .toList();
        final normalizedQuery = _searchQuery.trim().toLowerCase();
        final searchResults = normalizedQuery.isEmpty
            ? <Map<String, dynamic>>[]
            : allItems.where((item) {
                final searchable = [
                  item['name'],
                  item['type'],
                  item['note'],
                  item['brandId'],
                ].map((value) => value?.toString().toLowerCase() ?? '');
                return searchable.any((value) => value.contains(normalizedQuery));
              }).toList();

        List<Map<String, dynamic>> categoryFor(Map<String, dynamic> item) {
          final type = item['type']?.toString();
          if (type == 'Cadeaukaart') return giftCards;
          if (type == 'QR-code' || type == 'QR-set') return qrCodes;
          return cards;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F6),
          appBar: AppBar(
            title: const PremiumAppTitle('PasKluis'),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: const Color(0xFF333333),
            actions: [
              IconButton(
                tooltip: 'Instellingen',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
              IconButton(
                tooltip: 'Toevoegen',
                onPressed: showAddChoices,
                icon: const Icon(Icons.add, color: Color(0xFFD51B46), size: 32),
              ),
            ],
          ),
          body: MainTabSwipeRegion(
            currentIndex: 0,
            onSwitch: openTab,
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Zoek in PasKluis',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Zoekopdracht wissen',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (normalizedQuery.isNotEmpty)
                _SearchResults(
                  query: _searchQuery.trim(),
                  items: searchResults,
                  onTap: (item) => openCardView(categoryFor(item), item),
                )
              else ...[
              if (favorites.isNotEmpty) ...[
                _FavoritesSection(
                  items: favorites,
                  onItemTap: (item) => openCardView(categoryFor(item), item),
                ),
                const SizedBox(height: 24),
              ],
              _CategorySection(
                title: 'Klantenkaarten',
                icon: Icons.card_membership,
                items: getPreviewItems(cards),
                hasItems: cards.isNotEmpty,
                actionTitle: cards.isEmpty ? 'Voeg kaart toe' : 'Al je kaarten',
                onActionTap: cards.isEmpty
                    ? openLoyaltyAddFlow
                    : () => openTab(1),
                onItemTap: (item) => openCardView(cards, item),
                onItemLongPress: (item) => showItemOptions(context, item),
              ),
              const SizedBox(height: 28),
              _CategorySection(
                title: 'QR-codes',
                icon: Icons.qr_code,
                items: getPreviewItems(qrCodes),
                hasItems: qrCodes.isNotEmpty,
                actionTitle: qrCodes.isEmpty
                    ? 'Voeg QR-code toe'
                    : 'Al je QR-codes',
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
                onActionTap: giftCards.isEmpty
                    ? openGiftCardAddFlow
                    : () => openTab(3),
                onItemTap: (item) => openCardView(giftCards, item),
                onItemLongPress: (item) => showItemOptions(context, item),
              ),
              ],
            ],
            ),
          ),
          bottomNavigationBar: MainBottomNav(currentIndex: 0, onTap: openTab),
        );
      },
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onItemTap;

  const _FavoritesSection({required this.items, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star_rounded, color: Color(0xFFD5A021)),
            SizedBox(width: 8),
            Text(
              'Favorieten',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 190,
                child: _PreviewCard(
                  title: item['name']?.toString() ?? 'Kaart',
                  logoAsset: item['logoAsset']?.toString() ?? '',
                  customImage: item['customImage']?.toString() ?? '',
                  brandColor: item['brandColor']?.toString() ?? '',
                  balance: item['currentBalance']?.toString() ?? '',
                  type: item['type']?.toString() ?? '',
                  onTap: () => onItemTap(item),
                  onLongPress: () {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _SearchResults({
    required this.query,
    required this.items,
    required this.onTap,
  });

  static IconData _iconFor(String type) {
    if (type == 'Cadeaukaart') return Icons.card_giftcard_rounded;
    if (type == 'QR-code' || type == 'QR-set') return Icons.qr_code_2_rounded;
    return Icons.card_membership_rounded;
  }

  static String _labelFor(String type) {
    if (type == 'Cadeaukaart') return 'Cadeaukaart';
    if (type == 'QR-set') return 'QR-set';
    if (type == 'QR-code') return 'QR-code';
    return 'Klantenkaart';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              'Geen resultaten voor “$query”',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Zoek op de naam, het soort kaart of een notitie.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${items.length} ${items.length == 1 ? 'resultaat' : 'resultaten'}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((item) {
          final type = item['type']?.toString() ?? '';
          final name = item['name']?.toString().trim() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                onTap: () => onTap(item),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF8E3EA),
                  child: Icon(_iconFor(type), color: const Color(0xFFD51B46)),
                ),
                title: Text(
                  name.isEmpty ? _labelFor(type) : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(_labelFor(type)),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          );
        }),
      ],
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
            childAspectRatio: 1.58,
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
    final usesBrandBackground = useImage && widget.brandColor.isNotEmpty;

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
          child: Column(
            children: [
              Expanded(
                child: useImage
                    ? Center(
                        child: Transform.scale(
                          scale: hasCustomLogo ? 1.65 : 1.0,
                          child: hasCustomLogo
                              ? Image.file(
                                  File(widget.customImage),
                                  fit: BoxFit.contain,
                                  height: 72,
                                  width: double.infinity,
                                )
                              : SizedBox(
                                  height: 72,
                                  width: double.infinity,
                                  child: BrandLogo(source: widget.logoAsset),
                                ),
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
                    color: usesBrandBackground
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
                      color: usesBrandBackground
                          ? Colors.white
                          : const Color(0xFFD51B46),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
