import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/smart_card_import_service.dart';

enum SmartAddManualType { loyalty, qr, gift }

class SmartAddOutcome {
  final SmartCardImportResult? importResult;
  final SmartAddManualType? manualType;

  const SmartAddOutcome.import(this.importResult) : manualType = null;
  const SmartAddOutcome.manual(this.manualType) : importResult = null;
}

class SmartAddScreen extends StatefulWidget {
  const SmartAddScreen({super.key});

  @override
  State<SmartAddScreen> createState() => _SmartAddScreenState();
}

class _SmartAddScreenState extends State<SmartAddScreen> {
  bool analyzing = false;

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
      Navigator.pop(context, SmartAddOutcome.import(result));
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
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFD51B46),
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Hoe wil je de kaart toevoegen?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'PasKluis probeert het type, de winkel, code, pincode en het saldo alvast voor je in te vullen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFF626267),
              ),
            ),
            const SizedBox(height: 24),
            _SmartChoice(
              icon: Icons.photo_camera_rounded,
              title: 'Maak een foto',
              subtitle: 'Fotografeer de kaart en laat PasKluis hem herkennen',
              onTap: analyzing ? null : () => analyze(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _SmartChoice(
              icon: Icons.photo_library_rounded,
              title: 'Kies foto of screenshot',
              subtitle: 'Gebruik een kaart uit je mail of een andere app',
              onTap: analyzing ? null : () => analyze(ImageSource.gallery),
            ),
            if (analyzing) ...[
              const SizedBox(height: 18),
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFD51B46)),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('Kaart wordt herkend…')),
            ],
            const SizedBox(height: 28),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'of handmatig',
                    style: TextStyle(color: Color(0xFF77777B)),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ManualChoice(
                    icon: Icons.card_membership_rounded,
                    label: 'Klantenkaart',
                    onTap: () => manual(SmartAddManualType.loyalty),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ManualChoice(
                    icon: Icons.qr_code_rounded,
                    label: 'QR-code',
                    onTap: () => manual(SmartAddManualType.qr),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ManualChoice(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Cadeaukaart',
                    onTap: () => manual(SmartAddManualType.gift),
                  ),
                ),
              ],
            ),
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

class _ManualChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ManualChoice({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 94,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFD51B46), size: 27),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
