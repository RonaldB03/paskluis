import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../data/services/image_color_service.dart';
import '../../data/services/brand_sync_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_storage_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/card_share_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/templates/card_templates.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/logo_layout.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../../shared/widgets/main_tab_swipe_region.dart';
import '../../shared/widgets/premium_app_title.dart';
import '../../shared/widgets/main_tab_route.dart';

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
import '../scanner/smart_add_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _openedInitialTab = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  LocationAccessState _locationState = LocationAccessState.checking;
  DeviceLocation? _currentLocation;

  @override
  void initState() {
    super.initState();
    _refreshVisualAssets();
    if (SettingsService.locationCardsEnabled) {
      _loadNearbyLocation();
    } else {
      _locationState = LocationAccessState.permissionNeeded;
    }
    if (!_openedInitialTab) {
      _openedInitialTab = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final index = switch (SettingsService.defaultStartTab) {
          'cards' => 1,
          'qr' => 2,
          'gift' => 3,
          _ => 0,
        };
        if (index != 0) openTab(index);
      });
    }
  }

  Future<void> _loadNearbyLocation({bool requestPermission = false}) async {
    if (!SettingsService.locationCardsEnabled) {
      if (mounted) {
        setState(() {
          _locationState = LocationAccessState.permissionNeeded;
          _currentLocation = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _locationState = LocationAccessState.checking);
    }
    final snapshot = await LocationService.resolve(
      requestPermission: requestPermission,
    );
    if (!mounted) return;
    setState(() {
      _locationState = snapshot.state;
      _currentLocation = snapshot.location;
    });
  }

  Future<void> _handleNearbyAction() async {
    if (_locationState == LocationAccessState.permissionDeniedForever) {
      await LocationService.openAppSettings();
      return;
    }
    if (_locationState == LocationAccessState.servicesDisabled) {
      await LocationService.openLocationSettings();
      return;
    }
    await _loadNearbyLocation(requestPermission: true);
  }

  Future<void> _refreshVisualAssets() async {
    await _repairMovedCustomImages();
    await BrandSyncService.refreshSavedCards();
    await _repairMissingCustomLogoColors();
  }

  Future<void> _refreshHome() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SettingsService.refreshRemoteConfig();
    await Future.wait<void>([
      _loadNearbyLocation(),
      () async {
        try {
          await _refreshVisualAssets();
        } catch (_) {
          // Location refreshing must keep working while brand sync is offline.
        }
      }(),
    ]);
  }

  Future<void> _showAddHelp() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Een kaart toevoegen of importeren',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 22),
              const _AddHelpStep(
                number: '1',
                title: 'Tik op +',
                description:
                    'Kies Klantenkaart, QR-code of Cadeaukaart. PasKluis opent daarna de juiste invoer.',
              ),
              const _AddHelpStep(
                number: '2',
                title: 'Scan of vul handmatig in',
                description:
                    'Kies een winkel en scan de barcode of QR-code. Je kunt de code ook zelf invoeren.',
              ),
              const _AddHelpStep(
                number: '3',
                title: 'Importeer een foto of screenshot',
                description:
                    'PasKluis kan een klantenkaart, QR-code of cadeaukaart op je toestel herkennen. De afbeelding wordt niet geüpload.',
              ),
              const _AddHelpStep(
                number: '4',
                title: 'Controleer en bewaar',
                description:
                    'Controleer altijd de winkel en code voordat je de kaart opslaat.',
                showConnector: false,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showAddChoices();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Kaart toevoegen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        .where((item) =>
            item is Map &&
            item['type'] == type &&
            item['isArchived'] != true &&
            item['isArchived']?.toString() != 'true')
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  List<Map<String, dynamic>> getPreviewItems(List<Map<String, dynamic>> items) {
    final sorted = [...items];

    sorted.sort((a, b) {
      final aFavorite = a['isFavorite'] == true;
      final bFavorite = b['isFavorite'] == true;

      if (SettingsService.favoritesFirst && aFavorite != bFavorite) {
        return aFavorite ? -1 : 1;
      }

      if (SettingsService.cardSortOrder == 'alphabetical') {
        return (a['name']?.toString() ?? '').toLowerCase().compareTo(
              (b['name']?.toString() ?? '').toLowerCase(),
            );
      }

      if (SettingsService.cardSortOrder == 'added') {
        final aCreated =
            DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated =
            DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bCreated.compareTo(aCreated);
      }

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

    return sorted;
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
      'expiryDate': result['expiryDate'] ?? '',
      'expiryNotificationsEnabled': result['expiryNotificationsEnabled'] == 'true',
      'isArchived': result['isArchived'] == 'true',
    };

    await StorageService.addCard(card);
    try {
      await NotificationService.syncGiftCard(card);
    } catch (_) {
      // Saving the card is the primary action; reminders are best effort.
    }
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

    if (result['persisted'] != 'true') {
      await saveNewCard(result, forcedType: 'Cadeaukaart');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadeaukaart is opgeslagen.')),
      );
    }
  }

  Future<void> openSmartAdd() async {
    final outcome = await Navigator.push<SmartAddOutcome>(
      context,
      MaterialPageRoute(builder: (_) => const SmartAddScreen()),
    );
    if (!mounted || outcome == null) return;

    if (outcome.importResult == null && outcome.selectedType != null) {
      switch (outcome.selectedType!) {
        case SmartAddManualType.loyalty:
          await openLoyaltyAddFlow();
        case SmartAddManualType.qr:
          await openQrAddFlow();
        case SmartAddManualType.gift:
          await openGiftCardAddFlow();
      }
      return;
    }

    final result = outcome.importResult;
    if (result == null) return;
    final type = switch (outcome.selectedType) {
      SmartAddManualType.loyalty => 'Pasje',
      SmartAddManualType.qr => 'QR-code',
      SmartAddManualType.gift => 'Cadeaukaart',
      null => result.type,
    };

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
            initialCodeFormat: result.codeFormat,
            initialPinCode: result.pinCode,
            initialCurrentBalance: result.balance,
            initialBrandId: brand?.id,
            initialLogoAsset: brand?.logoAsset,
            initialBrandColor: brand?.color.value.toString(),
            initialLogoLayout: brand?.logoLayout ?? const {},
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
            initialCodeFormat: result.codeFormat,
            initialBrandId: brand?.id,
            initialLogoAsset: brand?.logoAsset,
            initialBrandColor: brand?.color.value.toString(),
            initialLogoLayout: brand == null
                ? const {}
                : logoLayoutCardFields(brand),
          ),
        ),
      );
    }

    if (!mounted || saved == null) return;
    if (type != 'Cadeaukaart' || saved['persisted'] != 'true') {
      await saveNewCard(saved, forcedType: type);
    }
    if (type == 'Cadeaukaart' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadeaukaart is opgeslagen.')),
      );
    }
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

    var saved = <String, dynamic>{
      ...oldItem,
      ...updated,
      'id': oldItem['id'],
      'type': 'Pasje',
      'createdAt': oldItem['createdAt'],
      'isFavorite': oldItem['isFavorite'] == true,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (saved['isShared'] == true ||
        (saved['sharedCardId']?.toString() ?? '').isNotEmpty) {
      saved = await CardShareService.updateSharedCard(saved);
    }
    await StorageService.saveCard(key, saved);
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
          initialCodeFormat: item['codeFormat']?.toString() ?? 'barcode',
          initialCardNumber: item['cardNumber']?.toString() ?? '',
          initialPinCode: item['pinCode']?.toString() ?? '',
          initialInitialBalance: item['initialBalance']?.toString() ?? '',
          initialCurrentBalance: item['currentBalance']?.toString() ?? '',
          initialNote: item['note']?.toString() ?? '',
          initialBrandId: item['brandId']?.toString() ?? '',
          initialLogoAsset: item['logoAsset']?.toString() ?? '',
          initialBrandColor: item['brandColor']?.toString() ?? '',
          initialCustomImage: item['customImage']?.toString() ?? '',
          initialExpiryDate: item['expiryDate']?.toString() ?? '',
          initialExpiryNotificationsEnabled:
              item['expiryNotificationsEnabled'] == true ||
              item['expiryNotificationsEnabled']?.toString() == 'true',
        ),
      ),
    );

    if (updated == null) return;

    final oldItem = Map<String, dynamic>.from(
      StorageService.cardsBox.get(key) as Map,
    );

    var saved = <String, dynamic>{
      ...oldItem,
      ...updated,
      'id': oldItem['id'],
      'type': 'Cadeaukaart',
      'createdAt': oldItem['createdAt'],
      'isFavorite': oldItem['isFavorite'] == true,
      'lastUsedAt': oldItem['lastUsedAt'] ?? '',
      'balanceHistory': oldItem['balanceHistory'] ?? '[]',
      'expiryDate': updated['expiryDate'] ?? oldItem['expiryDate'] ?? '',
      'expiryNotificationsEnabled':
          updated['expiryNotificationsEnabled'] == 'true',
      'isArchived': oldItem['isArchived'] ?? false,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (saved['isShared'] == true ||
        (saved['sharedCardId']?.toString() ?? '').isNotEmpty) {
      saved = await CardShareService.updateSharedCard(saved);
    }
    await StorageService.saveCard(key, saved);
    await NotificationService.syncGiftCard(saved);
  }

  Future<void> deleteItem(
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
          isShared ? 'Uit jouw PasKluis verwijderen?' : 'Verwijderen?',
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

  void showItemOptions(BuildContext context, Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Kaart';
    final type = item['type']?.toString() ?? '';
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
                  title: isShared
                      ? 'Uit mijn PasKluis verwijderen'
                      : 'Verwijderen',
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
    openSmartAdd();
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

    Navigator.of(context).pushAndRemoveUntil(
      mainTabRoute(screen, forward: true),
      (_) => false,
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
        final favorites = getPreviewItems(
          allItems.where((item) => item['isFavorite'] == true).toList(),
        );
        final nearbyItems = <Map<String, dynamic>>[];
        final currentLocation = _currentLocation;
        if (currentLocation != null) {
          nearbyItems.addAll(
            allItems.where((item) {
              final distance = LocationService.distanceTo(item, currentLocation);
              return distance != null &&
                  distance <= LocationService.nearbyRadiusMeters;
            }),
          );
          nearbyItems.sort((a, b) {
            final aDistance = LocationService.distanceTo(a, currentLocation) ??
                double.infinity;
            final bDistance = LocationService.distanceTo(b, currentLocation) ??
                double.infinity;
            return aDistance.compareTo(bDistance);
          });
        }
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
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Uitleg over kaarten toevoegen',
              onPressed: _showAddHelp,
              icon: const Icon(Icons.info_outline_rounded),
            ),
            title: const PremiumAppTitle('PasKluis'),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: const Color(0xFF333333),
            actions: [
              IconButton(
                tooltip: 'Instellingen',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  if (!mounted) return;
                  setState(() {});
                  await _loadNearbyLocation();
                },
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
            child: RefreshIndicator(
              onRefresh: _refreshHome,
              color: const Color(0xFFD51B46),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                  if (SettingsService.showFavoritesSection) ...[
                    _FavoritesSection(
                      items: favorites,
                      onItemTap: (item) => openCardView(categoryFor(item), item),
                      onItemLongPress: (item) => showItemOptions(context, item),
                    ),
                    const SizedBox(height: 26),
                  ],
                  if (SettingsService.locationCardsEnabled) ...[
                    _NearbySection(
                      state: _locationState,
                      items: nearbyItems,
                      onAction: _handleNearbyAction,
                      onItemTap: (item) => openCardView(categoryFor(item), item),
                      onItemLongPress: (item) => showItemOptions(context, item),
                    ),
                    const SizedBox(height: 28),
                  ],
                  _CategorySection(
                    title: 'Klantenkaarten',
                    icon: Icons.card_membership,
                    items: getPreviewItems(cards),
                    hasItems: cards.isNotEmpty,
                    actionTitle:
                        cards.isEmpty ? 'Voeg kaart toe' : 'Al je kaarten',
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
                    actionTitle: qrCodes.isEmpty
                        ? 'Voeg QR-code toe'
                        : 'Al je QR-codes',
                    onActionTap:
                        qrCodes.isEmpty ? openQrAddFlow : () => openTab(2),
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
  final ValueChanged<Map<String, dynamic>> onItemLongPress;

  const _FavoritesSection({
    required this.items,
    required this.onItemTap,
    required this.onItemLongPress,
  });

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
        if (items.isEmpty)
          const _HomeSectionPrompt(
            icon: Icons.star_border_rounded,
            title: 'Nog geen favorieten',
            subtitle: 'Markeer je belangrijkste kaarten met een ster.',
          )
        else
          _HomeCardStrip(
            items: items,
            onItemTap: onItemTap,
            onItemLongPress: onItemLongPress,
          ),
      ],
    );
  }
}

class _NearbySection extends StatelessWidget {
  final LocationAccessState state;
  final List<Map<String, dynamic>> items;
  final VoidCallback onAction;
  final ValueChanged<Map<String, dynamic>> onItemTap;
  final ValueChanged<Map<String, dynamic>> onItemLongPress;

  const _NearbySection({
    required this.state,
    required this.items,
    required this.onAction,
    required this.onItemTap,
    required this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (state == LocationAccessState.checking) {
      content = const SizedBox(
        height: 92,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (state == LocationAccessState.ready && items.isNotEmpty) {
      content = _HomeCardStrip(
        items: items,
        onItemTap: onItemTap,
        onItemLongPress: onItemLongPress,
      );
    } else if (state == LocationAccessState.ready) {
      content = const _HomeSectionPrompt(
        icon: Icons.location_history_rounded,
        title: 'Nog geen kaart op deze plek',
        subtitle:
            'Open een kaart bij een winkel. PasKluis onthoudt die plek alleen op dit toestel.',
      );
    } else if (state == LocationAccessState.servicesDisabled) {
      content = _HomeSectionPrompt(
        icon: Icons.location_disabled_rounded,
        title: 'Locatievoorzieningen staan uit',
        subtitle: 'Zet locatie aan om eerder gebruikte kaarten hier te tonen.',
        actionLabel: 'Locatie aanzetten',
        onAction: onAction,
      );
    } else if (state == LocationAccessState.permissionDeniedForever) {
      content = _HomeSectionPrompt(
        icon: Icons.location_off_rounded,
        title: 'Locatie staat uit voor PasKluis',
        subtitle: 'Je kunt dit aanpassen in de instellingen van je telefoon.',
        actionLabel: 'Open instellingen',
        onAction: onAction,
      );
    } else if (state == LocationAccessState.permissionNeeded) {
      content = _HomeSectionPrompt(
        icon: Icons.near_me_outlined,
        title: 'Toon kaarten die je hier gebruikt',
        subtitle: 'Je locatie blijft op je telefoon en wordt niet geüpload.',
        actionLabel: 'Locatie gebruiken',
        onAction: onAction,
      );
    } else {
      content = _HomeSectionPrompt(
        icon: Icons.location_searching_rounded,
        title: 'Locatie niet beschikbaar',
        subtitle: 'Probeer het opnieuw wanneer je bereik hebt.',
        actionLabel: 'Opnieuw',
        onAction: onAction,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.near_me_rounded, color: Color(0xFFD51B46)),
            SizedBox(width: 8),
            Text(
              'In de buurt',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }
}

class _HomeCardStrip extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onItemTap;
  final ValueChanged<Map<String, dynamic>> onItemLongPress;

  const _HomeCardStrip({
    required this.items,
    required this.onItemTap,
    required this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = ((constraints.maxWidth - 16) / 3)
            .clamp(96.0, 142.0)
            .toDouble();
        final cardHeight = (cardWidth / 1.18).clamp(88.0, 112.0).toDouble();
        return SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: cardWidth,
                child: HomePreviewCard(
                  item: item,
                  title: item['name']?.toString() ?? 'Kaart',
                  logoAsset: item['logoAsset']?.toString() ?? '',
                  customImage: item['customImage']?.toString() ?? '',
                  brandColor: item['brandColor']?.toString() ?? '',
                  balance: item['currentBalance']?.toString() ?? '',
                  type: item['type']?.toString() ?? '',
                  onTap: () => onItemTap(item),
                  onLongPress: () => onItemLongPress(item),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _HomeSectionPrompt extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _HomeSectionPrompt({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF8E3EA),
            child: Icon(icon, color: const Color(0xFFD51B46)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
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
  final ValueChanged<Map<String, dynamic>> onItemTap;
  final ValueChanged<Map<String, dynamic>> onItemLongPress;

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
        _ResponsiveSectionHeader(
          title: title,
          icon: icon,
          actionTitle: hasItems ? actionTitle : '',
          onActionTap: onActionTap,
        ),
        const SizedBox(height: 12),
        if (!hasItems)
          _EmptyCategoryCard(
            title: actionTitle,
            icon: icon,
            onTap: onActionTap,
          )
        else
          _HomeCardStrip(
            items: items,
            onItemTap: onItemTap,
            onItemLongPress: onItemLongPress,
          ),
      ],
    );
  }
}

class _ResponsiveSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String actionTitle;
  final VoidCallback onActionTap;

  const _ResponsiveSectionHeader({
    required this.title,
    required this.icon,
    required this.actionTitle,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Color(0xFF333333),
    );
    final actionStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: const Color(0xFF56649A),
      fontWeight: FontWeight.w500,
    );
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    double textWidth(String value, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      return painter.width;
    }

    final actionButton = TextButton(
      onPressed: onActionTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(actionTitle, maxLines: 1, style: actionStyle),
    );

    final titleRow = Row(
      children: [
        Icon(icon, color: const Color(0xFFD51B46)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
      ],
    );

    if (actionTitle.isEmpty) return titleRow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final requiredWidth =
            24 +
            8 +
            textWidth(title, titleStyle) +
            12 +
            textWidth(actionTitle, actionStyle) +
            12;
        final fitsOnOneLine = requiredWidth <= constraints.maxWidth;

        if (fitsOnOneLine) {
          return Row(
            children: [
              Icon(icon, color: const Color(0xFFD51B46)),
              const SizedBox(width: 8),
              Text(title, maxLines: 1, style: titleStyle),
              const Spacer(),
              actionButton,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleRow,
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: actionButton),
          ],
        );
      },
    );
  }
}

class _EmptyCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _EmptyCategoryCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0D9E0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0B000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFEEF2), Color(0xFFF8DDE6)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: const Color(0xFFD51B46), size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF302D34),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Veilig opgeslagen op dit toestel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF77717D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFD51B46),
                child: Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePreviewCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String title;
  final String logoAsset;
  final String customImage;
  final String brandColor;
  final String balance;
  final String type;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const HomePreviewCard({
    super.key,
    required this.item,
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
  State<HomePreviewCard> createState() => _HomePreviewCardState();
}

class _HomePreviewCardState extends State<HomePreviewCard> {
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
    final hasDarkBrandBackground =
        usesBrandBackground && cardColor.computeLuminance() < 0.55;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 150;
        final logoHeight = compact ? 42.0 : 72.0;
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
              padding: EdgeInsets.all(compact ? 8 : 14),
              decoration: BoxDecoration(
                color: usesBrandBackground ? cardColor : Colors.white,
                borderRadius: BorderRadius.circular(compact ? 15 : 18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isPressed ? 0.035 : 0.06,
                    ),
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
                              scale: hasCustomLogo && !compact ? 1.18 : 1.0,
                              child: hasCustomLogo
                                  ? Image.file(
                                      File(widget.customImage),
                                      fit: BoxFit.contain,
                                      height: logoHeight,
                                      width: double.infinity,
                                    )
                                  : SizedBox(
                                      height: logoHeight,
                                      width: double.infinity,
                                      child: BrandLogo(
                                        source: widget.logoAsset,
                                        scale: logoLayoutValue(
                                          widget.item,
                                          'home',
                                          'scale',
                                          1,
                                        ),
                                        offsetX: logoLayoutValue(
                                          widget.item,
                                          'home',
                                          'x',
                                          0,
                                        ),
                                        offsetY: logoLayoutValue(
                                          widget.item,
                                          'home',
                                          'y',
                                          0,
                                        ),
                                      ),
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
                                fontSize: compact ? 12 : 17,
                                fontWeight: FontWeight.w800,
                                color: hasAssetLogo
                                    ? Colors.white
                                    : const Color(0xFF333333),
                              ),
                            ),
                          ),
                  ),
                  if (isGiftCard) ...[
                    SizedBox(height: compact ? 4 : 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 7),
                      decoration: BoxDecoration(
                        color: hasDarkBrandBackground
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFFF8E3EA),
                        borderRadius: BorderRadius.circular(compact ? 10 : 14),
                      ),
                      child: Text(
                        widget.balance.isEmpty
                            ? 'Saldo onbekend'
                            : '€ ${formatAmountValue(widget.balance)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 11.5 : 15,
                          fontWeight: FontWeight.w900,
                          color: hasDarkBrandBackground
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
      },
    );
  }
}

class _AddHelpStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final bool showConnector;

  const _AddHelpStep({
    required this.number,
    required this.title,
    required this.description,
    this.showConnector = true,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFD51B46),
                  foregroundColor: Colors.white,
                  child: Text(
                    number,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: const Color(0xFFE4E4E8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: Color(0xFF55555A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
