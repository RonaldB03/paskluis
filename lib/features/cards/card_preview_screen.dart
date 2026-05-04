import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cards_screen.dart';
import 'edit_card_screen.dart';

class CardPreviewScreen extends StatefulWidget {
  final Map<String, String> item;

  const CardPreviewScreen({
    super.key,
    required this.item,
  });

  @override
  State<CardPreviewScreen> createState() => _CardPreviewScreenState();
}

class _CardPreviewScreenState extends State<CardPreviewScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, String> item;
  late AnimationController animationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();

    item = Map<String, String>.from(widget.item);

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOut,
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    animationController.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  Color get brandColor {
    final raw = item['brandColor'] ?? '';
    final parsed = int.tryParse(raw);

    if (parsed != null) return Color(parsed);
    return const Color(0xFFD51B46);
  }

  Barcode get barcodeType {
    final code = item['code'] ?? '';
    final onlyDigits = RegExp(r'^\d+$').hasMatch(code);

    if (onlyDigits && code.length == 13) return Barcode.ean13();
    if (onlyDigits && code.length == 8) return Barcode.ean8();

    return Barcode.code128();
  }

  String get formattedCode {
    final code = item['code'] ?? '';

    return code
        .replaceAllMapped(
      RegExp(r'.{1,4}'),
          (match) => '${match.group(0)} ',
    )
        .trim();
  }

  Future<void> openEdit() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditCardScreen(item: item),
      ),
    );

    if (!mounted || updated == null) return;

    setState(() {
      item = updated.map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
    });
  }

  void goToCardsScreen() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const CardsScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = item['name'] ?? 'Kaart';
    final code = item['code'] ?? '';
    final logoAsset = item['logoAsset'] ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        goToCardsScreen();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F4F6),
          elevation: 0,
          centerTitle: true,
          foregroundColor: const Color(0xFF2F2F34),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: goToCardsScreen,
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            TextButton(
              onPressed: openEdit,
              child: const Text(
                'Bewerken',
                style: TextStyle(
                  color: Color(0xFFD51B46),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        colors: [
                          brandColor,
                          brandColor.withOpacity(0.82),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: brandColor.withOpacity(0.30),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Column(
                        children: [
                          Container(
                            height: 138,
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            child: logoAsset.isNotEmpty
                                ? Image.asset(
                              logoAsset,
                              fit: BoxFit.contain,
                            )
                                : const Icon(
                              Icons.card_membership_rounded,
                              color: Colors.white,
                              size: 70,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(32),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F7F8),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: BarcodeWidget(
                                    barcode: barcodeType,
                                    data: code,
                                    width: double.infinity,
                                    height: 118,
                                    drawText: false,
                                    errorBuilder: (_, __) {
                                      return const Text(
                                        'Barcode kan niet worden weergegeven',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  formattedCode,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    letterSpacing: 2,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F1F24),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  _InfoBlock(
                    title: 'Kaart opgeslagen',
                    subtitle:
                    'Deze klantenkaart staat nu in je PasKluis en is klaar voor gebruik.',
                    icon: Icons.check_circle_rounded,
                    color: brandColor,
                  ),

                  const SizedBox(height: 14),

                  _PreviewAction(
                    icon: Icons.edit_note_rounded,
                    title: 'Gegevens aanpassen',
                    subtitle: 'Naam, code of notities wijzigen',
                    onTap: openEdit,
                  ),

                  const SizedBox(height: 10),

                  _PreviewAction(
                    icon: Icons.photo_camera_outlined,
                    title: 'Kaartfoto’s',
                    subtitle: 'Voeg later een foto van je kaart toe',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kaartfoto’s voegen we later toe.'),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  _PreviewAction(
                    icon: Icons.notes_rounded,
                    title: 'Notities',
                    subtitle: 'Bewaar extra informatie bij deze kaart',
                    onTap: openEdit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _InfoBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.14),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2F2F34),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    color: Colors.black.withOpacity(0.56),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PreviewAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFD51B46).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFD51B46),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF2F2F34),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.48),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}