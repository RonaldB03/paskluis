import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/smart_card_import_service.dart';

enum SmartAddManualType { loyalty, qr, gift }

class SmartAddOutcome {
  final SmartCardImportResult? importResult;
  final SmartAddManualType? selectedType;

  const SmartAddOutcome.import(this.importResult, this.selectedType);
  const SmartAddOutcome.manual(this.selectedType) : importResult = null;
}

class SmartAddScreen extends StatefulWidget {
  const SmartAddScreen({super.key});

  @override
  State<SmartAddScreen> createState() => _SmartAddScreenState();
}

class _SmartAddScreenState extends State<SmartAddScreen> {
  bool analyzing = false;
  SmartAddManualType? selectedType;

  Future<void> analyze(ImageSource source) async {
    if (analyzing) return;
    HapticFeedback.selectionClick();
    setState(() => analyzing = true);

    try {
      final result = await SmartCardImportService.pickAndAnalyze(source: source);
      if (!mounted) return;
      if (result == null) {
        setState(() => analyzing = false);
        return;
      }
      Navigator.pop(context, SmartAddOutcome.import(result, selectedType));
    } catch (_) {
      if (!mounted) return;
      setState(() => analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Deze afbeelding kon niet worden gelezen. Probeer het opnieuw.',
          ),
        ),
      );
    }
  }

  void manual(SmartAddManualType type) {
    Navigator.pop(context, SmartAddOutcome.manual(type));
  }

  String get selectedLabel => switch (selectedType) {
    SmartAddManualType.loyalty => 'klantenkaart',
    SmartAddManualType.qr => 'QR-code',
    SmartAddManualType.gift => 'cadeaukaart',
    null => 'kaart',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        foregroundColor: const Color(0xFF303036),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Kaart toevoegen',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Icon(
              selectedType == null
                  ? Icons.add_card_rounded
                  : Icons.auto_awesome_rounded,
              color: Color(0xFFD51B46),
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              selectedType == null
                  ? 'Wat wil je toevoegen?'
                  : 'Hoe wil je deze $selectedLabel toevoegen?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              selectedType == null
                  ? 'Kies eerst het soort kaart. Daarna kies je scannen, zelf invoeren of importeren uit een screenshot.'
                  : 'Je kunt een winkel kiezen en de code scannen, alles zelf invoeren, of gegevens uit een screenshot laten herkennen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFF626267),
              ),
            ),
            const SizedBox(height: 24),
            if (selectedType == null) ...[
              _SmartChoice(
                icon: Icons.card_membership_rounded,
                title: 'Klantenkaart',
                subtitle: 'Voeg een klantenkaart of ledenpas toe',
                onTap: () => setState(
                  () => selectedType = SmartAddManualType.loyalty,
                ),
              ),
              const SizedBox(height: 12),
              _SmartChoice(
                icon: Icons.qr_code_rounded,
                title: 'QR-code',
                subtitle: 'Voeg één QR-code of meerdere tickets toe',
                onTap: () => setState(
                  () => selectedType = SmartAddManualType.qr,
                ),
              ),
              const SizedBox(height: 12),
              _SmartChoice(
                icon: Icons.card_giftcard_rounded,
                title: 'Cadeaukaart',
                subtitle: 'Voeg een cadeaukaart met eventueel saldo toe',
                onTap: () => setState(
                  () => selectedType = SmartAddManualType.gift,
                ),
              ),
            ] else ...[
              _SmartChoice(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Winkel kiezen of zelf invoeren',
                subtitle: selectedType == SmartAddManualType.qr
                    ? 'Scan de QR-code of voer de gegevens zelf in'
                    : 'Kies een winkel, scan de barcode of kies Handmatig',
                onTap: () => manual(selectedType!),
              ),
              const SizedBox(height: 12),
              _SmartChoice(
                icon: Icons.photo_library_rounded,
                title: 'Importeren uit screenshot',
                subtitle: 'Kies een afbeelding uit je fotobibliotheek',
                onTap: analyzing ? null : () => analyze(ImageSource.gallery),
              ),
            ],
            if (analyzing) ...[
              const SizedBox(height: 18),
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFD51B46)),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('Kaart wordt herkend…')),
            ],
            if (selectedType != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: analyzing
                    ? null
                    : () => setState(() => selectedType = null),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Ander type kiezen'),
              ),
            ],
            const SizedBox(height: 22),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Color(0xFF77777B),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Herkenning gebeurt op je toestel; je foto wordt niet geüpload.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF77777B)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartChoice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SmartChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
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
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8EE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFFD51B46), size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Color(0xFF66666A),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFAAAAAE)),
            ],
          ),
        ),
      ),
    );
  }
}
