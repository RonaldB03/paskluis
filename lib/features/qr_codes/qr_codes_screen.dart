import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../shared/widgets/main_bottom_nav.dart';

import '../cards/cards_screen.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../home/home_screen.dart';

import 'add_qr_code_screen.dart';
import 'choose_qr_code_screen.dart';
import 'edit_qr_set_screen.dart';

class QrCodesScreen extends StatelessWidget {
  const QrCodesScreen({super.key});

  bool isQrItem(Map item) {
    final type = item['type']?.toString() ?? '';
    return type == 'QR-code' || type == 'QR-set';
  }

  List<Map<String, dynamic>> getItems() {
    final items = StorageService.cardsBox.values
        .where((item) => item is Map && isQrItem(item))
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
      if (value is Map && value['id']?.toString() == id) return key;
    }

    return null;
  }

  List<String> parseCodes(Map<String, dynamic> item) {
    if (item['type']?.toString() == 'QR-set') {
      return (item['codes']?.toString() ?? '')
          .split('|||')
          .where((code) => code.trim().isNotEmpty)
          .toList();
    }

    final code = item['code']?.toString() ?? '';
    return code.trim().isEmpty ? [] : [code];
  }

  List<bool> parseUsed(Map<String, dynamic> item, int count) {
    final raw = item['used']?.toString() ?? '';

    if (raw.isEmpty) {
      return List.filled(count, false);
    }

    final values = raw.split('|||').map((v) => v == 'true').toList();

    while (values.length < count) {
      values.add(false);
    }

    return values.take(count).toList();
  }

  Future<void> openAddQrCode(BuildContext context) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseQrCodeScreen(),
      ),
    );

    if (!context.mounted || result == null) return;

    await saveNewQrCode(result);
  }

  Future<void> saveNewQrCode(Map<String, String> result) async {
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

    await StorageService.cardsBox.add({
      'id': result['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'QR-code',
      'name': result['name'] ?? '',
      'code': result['code'] ?? '',
      'codes': '',
      'used': '',
      'note': result['note'] ?? '',
      'cardNumber': '',
      'pinCode': '',
      'initialBalance': '',
      'currentBalance': '',
      'brandId': result['brandId'] ?? '',
      'logoAsset': result['logoAsset'] ?? '',
      'brandColor': result['brandColor'] ?? '',
      'customImage': result['customImage'] ?? '',
      'isFavorite': result['isFavorite'] == 'true',
      'createdAt': result['createdAt'] ?? now,
      'updatedAt': result['updatedAt'] ?? now,
      'lastUsedAt': result['lastUsedAt'] ?? '',
      'balanceHistory': '[]',
    });
  }

  Future<void> editQrCode(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    if (item['type']?.toString() == 'QR-set') {
      final key = findHiveKey(item);
      if (key == null) return;

      final updated = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => EditQrSetScreen(item: item),
        ),
      );

      if (!context.mounted || updated == null) return;

      final oldItem = Map<String, dynamic>.from(
        StorageService.cardsBox.get(key) as Map,
      );

      await StorageService.cardsBox.put(key, {
        ...oldItem,
        ...updated,
        'id': oldItem['id'],
        'type': 'QR-set',
        'createdAt': oldItem['createdAt'],
        'isFavorite': oldItem['isFavorite'] == true,
        'lastUsedAt': oldItem['lastUsedAt'] ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return;
    }

    final key = findHiveKey(item);
    if (key == null) return;

    final updated = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddQrCodeScreen(
          isEditing: true,
          initialName: item['name']?.toString() ?? '',
          initialCode: item['code']?.toString() ?? '',
          initialNote: item['note']?.toString() ?? '',
          initialBrandId: item['brandId']?.toString() ?? '',
          initialLogoAsset: item['logoAsset']?.toString() ?? '',
          initialBrandColor: item['brandColor']?.toString() ?? '',
          initialCustomImage: item['customImage']?.toString() ?? '',
        ),
      ),
    );

    if (!context.mounted || updated == null) return;

    final oldItem = Map<String, dynamic>.from(
      StorageService.cardsBox.get(key) as Map,
    );

    await StorageService.cardsBox.put(key, {
      ...oldItem,
      ...updated,
      'id': oldItem['id'],
      'type': 'QR-code',
      'createdAt': oldItem['createdAt'],
      'isFavorite': oldItem['isFavorite'] == true,
      'lastUsedAt': oldItem['lastUsedAt'] ?? '',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> toggleFavorite(Map<String, dynamic> item) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final oldItem = Map<String, dynamic>.from(
      StorageService.cardsBox.get(key) as Map,
    );

    await StorageService.cardsBox.put(key, {
      ...oldItem,
      'isFavorite': oldItem['isFavorite'] != true,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteQrCode(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final name = item['name']?.toString() ?? 'deze QR-code';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('QR-code verwijderen?'),
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
        return;
      case 3:
        screen = const GiftCardsScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void openQrView(
      BuildContext context,
      List<Map<String, dynamic>> items,
      int index,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrCodeViewScreen(
          items: items,
          initialIndex: index,
        ),
      ),
    );
  }

  void showQrOptions(BuildContext context, Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'QR-code';
    final isFavorite = item['isFavorite'] == true;

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
                  icon: isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  title: isFavorite
                      ? 'Verwijderen uit favorieten'
                      : 'Toevoegen aan favorieten',
                  onTap: () {
                    Navigator.pop(context);
                    toggleFavorite(item);
                  },
                ),
                _OptionTile(
                  icon: Icons.edit_rounded,
                  title: 'Bewerken',
                  onTap: () {
                    Navigator.pop(context);
                    editQrCode(context, item);
                  },
                ),
                _OptionTile(
                  icon: Icons.delete_rounded,
                  title: 'Verwijderen',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    deleteQrCode(context, item);
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
            title: const Text(
              'QR-codes',
              style: TextStyle(fontWeight: FontWeight.w800),
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
                onPressed: () => openAddQrCode(context),
              ),
            ],
          ),
          body: items.isEmpty
              ? _EmptyQrState(
            onAdd: () => openAddQrCode(context),
          )
              : GridView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: items.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final item = items[index];

              return _QrTile(
                item: item,
                onTap: () => openQrView(context, items, index),
                onLongPress: () => showQrOptions(context, item),
              );
            },
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 2,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
    );
  }
}

class QrCodeViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;

  const QrCodeViewScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<QrCodeViewScreen> createState() => _QrCodeViewScreenState();
}

class _QrCodeViewScreenState extends State<QrCodeViewScreen> {
  late final PageController pageController;
  late int currentIndex;
  late int ticketIndex;

  Map<String, dynamic> get item => widget.items[currentIndex];

  bool get isSet => item['type']?.toString() == 'QR-set';

  List<String> get currentCodes {
    if (isSet) {
      return (item['codes']?.toString() ?? '')
          .split('|||')
          .where((code) => code.trim().isNotEmpty)
          .toList();
    }

    final code = item['code']?.toString() ?? '';
    return code.trim().isEmpty ? [] : [code];
  }

  List<bool> get currentUsed {
    final codes = currentCodes;
    final raw = item['used']?.toString() ?? '';

    if (raw.isEmpty) {
      return List.filled(codes.length, false);
    }

    final values = raw.split('|||').map((v) => v == 'true').toList();

    while (values.length < codes.length) {
      values.add(false);
    }

    return values.take(codes.length).toList();
  }

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    ticketIndex = 0;
    pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  dynamic findHiveKey(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';

    for (final key in StorageService.cardsBox.keys) {
      final value = StorageService.cardsBox.get(key);
      if (value is Map && value['id']?.toString() == id) return key;
    }

    return null;
  }

  Future<void> saveCurrentItem(Map<String, dynamic> updated) async {
    final key = findHiveKey(item);
    if (key == null) return;

    await StorageService.cardsBox.put(key, updated);

    setState(() {
      widget.items[currentIndex] = Map<String, dynamic>.from(updated);
    });
  }

  Future<void> markCurrentTicketAsUsed() async {
    final codes = currentCodes;
    if (codes.isEmpty) return;

    final used = currentUsed;
    used[ticketIndex] = true;

    final updated = Map<String, dynamic>.from(item);
    updated['used'] = used.map((v) => v ? 'true' : 'false').join('|||');
    updated['lastUsedAt'] = DateTime.now().toIso8601String();
    updated['updatedAt'] = DateTime.now().toIso8601String();

    await saveCurrentItem(updated);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSet
              ? 'Ticket ${ticketIndex + 1} gemarkeerd als gebruikt.'
              : 'QR-code gemarkeerd als gebruikt.',
        ),
      ),
    );
  }

  Future<void> toggleFavorite() async {
    final updated = Map<String, dynamic>.from(item);
    updated['isFavorite'] = updated['isFavorite'] != true;
    updated['updatedAt'] = DateTime.now().toIso8601String();

    await saveCurrentItem(updated);
  }

  void nextTicket() {
    final codes = currentCodes;
    if (codes.isEmpty) return;

    final next = ticketIndex + 1;

    if (next >= codes.length) {
      setState(() => ticketIndex = 0);
    } else {
      setState(() => ticketIndex = next);
    }
  }

  int firstUnusedIndex() {
    final used = currentUsed;

    for (int i = 0; i < used.length; i++) {
      if (!used[i]) return i;
    }

    return 0;
  }

  void showFirstUnused() {
    setState(() {
      ticketIndex = firstUnusedIndex();
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'QR-code';
    final isFavorite = item['isFavorite'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4F4F6),
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: toggleFavorite,
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: const Color(0xFFD51B46),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: pageController,
        itemCount: widget.items.length,
        onPageChanged: (index) {
          setState(() {
            currentIndex = index;
            ticketIndex = 0;
          });
        },
        itemBuilder: (context, index) {
          final current = widget.items[index];
          final isCurrentSet = current['type']?.toString() == 'QR-set';

          final codes = isCurrentSet
              ? (current['codes']?.toString() ?? '')
              .split('|||')
              .where((code) => code.trim().isNotEmpty)
              .toList()
              : [
            current['code']?.toString() ?? '',
          ].where((code) => code.trim().isNotEmpty).toList();

          final rawUsed = current['used']?.toString() ?? '';
          final used = rawUsed.isEmpty
              ? List.filled(codes.length, false)
              : rawUsed.split('|||').map((v) => v == 'true').toList();

          while (used.length < codes.length) {
            used.add(false);
          }

          final safeTicketIndex =
          ticketIndex >= codes.length ? 0 : ticketIndex;

          final currentName = current['name']?.toString() ?? 'QR-code';
          final currentCode =
          codes.isEmpty ? '' : codes[safeTicketIndex].trim();
          final currentNote = current['note']?.toString() ?? '';
          final currentUsed =
          used.isEmpty ? false : used[safeTicketIndex] == true;

          final usedCount = used.where((value) => value == true).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.055),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      currentName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF333333),
                      ),
                    ),
                    if (isCurrentSet) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ticket ${safeTicketIndex + 1} van ${codes.length} • $usedCount gebruikt',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (currentCode.isEmpty)
                            const SizedBox(
                              height: 245,
                              child: Center(
                                child: Text('Geen QR-code gevonden'),
                              ),
                            )
                          else
                            QrImageView(
                              data: currentCode,
                              version: QrVersions.auto,
                              size: 245,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                          if (currentUsed)
                            Container(
                              width: 245,
                              height: 245,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.86),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text(
                                  'GEBRUIKT',
                                  style: TextStyle(
                                    color: Color(0xFFD51B46),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SelectableText(
                      currentCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555557),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (isCurrentSet) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: showFirstUnused,
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Eerste ongebruikte'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD51B46),
                            side: const BorderSide(
                              color: Color(0xFFD51B46),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: nextTicket,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Volgende'),
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
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: currentUsed ? null : markCurrentTicketAsUsed,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    currentUsed
                        ? 'Al gebruikt'
                        : isCurrentSet
                        ? 'Dit ticket gebruikt'
                        : 'QR-code gebruikt',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD51B46),
                    disabledBackgroundColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (currentNote.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    currentNote,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.35,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyQrState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyQrState({
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
                Icons.qr_code_2_rounded,
                size: 48,
                color: Color(0xFFD51B46),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Nog geen QR-codes toegevoegd',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Voeg bijvoorbeeld een ticket, toegangscode, link of andere QR-code toe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: Color(0xFF555557),
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('QR-code toevoegen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QrTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  List<String> get codes {
    if (item['type']?.toString() == 'QR-set') {
      return (item['codes']?.toString() ?? '')
          .split('|||')
          .where((code) => code.trim().isNotEmpty)
          .toList();
    }

    final code = item['code']?.toString() ?? '';
    return code.trim().isEmpty ? [] : [code];
  }

  List<bool> get used {
    final raw = item['used']?.toString() ?? '';
    final values = raw.isEmpty
        ? List.filled(codes.length, false)
        : raw.split('|||').map((v) => v == 'true').toList();

    while (values.length < codes.length) {
      values.add(false);
    }

    return values.take(codes.length).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = item['name']?.toString() ?? 'QR-code';
    final isFavorite = item['isFavorite'] == true;
    final isSet = item['type']?.toString() == 'QR-set';
    final firstCode = codes.isEmpty ? '' : codes.first;
    final usedCount = used.where((value) => value == true).length;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: firstCode.isEmpty
                        ? const Icon(
                      Icons.qr_code_2_rounded,
                      size: 64,
                      color: Color(0xFFD51B46),
                    )
                        : QrImageView(
                      data: firstCode,
                      version: QrVersions.auto,
                      size: 86,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333333),
                  ),
                ),
                if (isSet) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${codes.length} tickets • $usedCount gebruikt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.48),
                    ),
                  ),
                ],
              ],
            ),
            if (isFavorite)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.star_rounded,
                  color: Color(0xFFD51B46),
                  size: 22,
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