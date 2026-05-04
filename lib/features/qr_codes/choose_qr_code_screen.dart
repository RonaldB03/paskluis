import 'package:flutter/material.dart';

import 'add_qr_code_screen.dart';
import 'multi_qr_scanner_screen.dart';
import 'qr_scanner_screen.dart';

class ChooseQrCodeScreen extends StatelessWidget {
  const ChooseQrCodeScreen({super.key});

  Future<void> openManual(BuildContext context) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddQrCodeScreen(),
      ),
    );

    if (!context.mounted || result == null) return;

    Navigator.pop(context, result);
  }

  Future<void> openScanner(BuildContext context) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(),
      ),
    );

    if (!context.mounted || code == null || code.trim().isEmpty) return;

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddQrCodeScreen(
          initialCode: code.trim(),
        ),
      ),
    );

    if (!context.mounted || result == null) return;

    Navigator.pop(context, result);
  }

  Future<void> openMultiScanner(BuildContext context) async {
    final codes = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const MultiQrScannerScreen(),
      ),
    );

    if (!context.mounted || codes == null || codes.isEmpty) return;

    final nameController = TextEditingController(
      text: 'QR-codes (${codes.length})',
    );

    final setName = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Naam voor QR-set'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Naam',
              hintText: 'Bijv. Festival tickets',
            ),
            onSubmitted: (_) {
              final value = nameController.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () {
                final value = nameController.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(context, value);
              },
              child: const Text('Opslaan'),
            ),
          ],
        );
      },
    );

    nameController.dispose();

    if (!context.mounted || setName == null || setName.trim().isEmpty) return;

    final now = DateTime.now().toIso8601String();

    Navigator.pop(context, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'QR-set',
      'name': setName.trim(),
      'code': '',
      'note': '',
      'codes': codes.join('|||'),
      'used': List.filled(codes.length, 'false').join('|||'),
      'isFavorite': 'false',
      'createdAt': now,
      'updatedAt': now,
      'lastUsedAt': '',
    });
  }

  void showImageImportComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Importeren uit afbeelding voegen we later toe.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
        foregroundColor: const Color(0xFF303036),
        centerTitle: true,
        title: const Text(
          'QR-code toevoegen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => openManual(context),
            child: const Text(
              'Handmatig',
              style: TextStyle(
                color: Color(0xFFD51B46),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text(
            'Hoe wil je je QR-code toevoegen?',
            style: TextStyle(
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF303036),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan één QR-code of meerdere tickets achter elkaar.',
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: Color(0xFF555557),
            ),
          ),
          const SizedBox(height: 22),
          _QrChoiceTile(
            icon: Icons.qr_code_scanner_rounded,
            title: '1 QR-code scannen',
            subtitle: 'Gebruik je camera om één QR-code toe te voegen',
            onTap: () => openScanner(context),
          ),
          const SizedBox(height: 10),
          _QrChoiceTile(
            icon: Icons.confirmation_number_rounded,
            title: 'Meerdere QR-codes',
            subtitle: 'Scan meerdere tickets achter elkaar en sla ze als set op',
            onTap: () => openMultiScanner(context),
          ),
          const SizedBox(height: 10),
          _QrChoiceTile(
            icon: Icons.edit_note_rounded,
            title: 'Handmatig invoeren',
            subtitle: 'Voer zelf een naam en QR-code inhoud in',
            onTap: () => openManual(context),
          ),
          const SizedBox(height: 10),
          _QrChoiceTile(
            icon: Icons.image_rounded,
            title: 'Uit afbeelding importeren',
            subtitle: 'Deze optie bouwen we later uit',
            isDisabled: true,
            onTap: () => showImageImportComingSoon(context),
          ),
        ],
      ),
    );
  }
}

class _QrChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDisabled;

  const _QrChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisabled ? Colors.grey : const Color(0xFFD51B46);

    return Material(
      color: Colors.white,
      elevation: 0.8,
      shadowColor: Colors.black.withOpacity(0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF303036),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF555557),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDisabled ? Colors.grey.shade300 : Colors.black26,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}