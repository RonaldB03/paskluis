import 'package:paskluis_v1/l10n/l10n.dart';
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
         SnackBar(
          content: Text(
            L10n.current.thisImageCouldNotBeReadPlease,
          ),
        ),
      );
    }
  }

  void manual(SmartAddManualType type) {
    Navigator.pop(context, SmartAddOutcome.manual(type));
  }

  String get selectedLabel => switch (selectedType) {
    SmartAddManualType.loyalty => L10n.current.loyaltyCard.toLowerCase(),
    SmartAddManualType.qr => L10n.current.qrCode,
    SmartAddManualType.gift => L10n.current.giftCard.toLowerCase(),
    null => 'kaart',
  };

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        foregroundColor: const Color(0xFF303036),
        elevation: 0,
        centerTitle: true,
        title:  Text(
          L10n.current.addCard,
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
                  ? L10n.current.whatWouldYouLikeToAdd
                  : L10n.current.howWouldYouLikeToAddThis((selectedLabel).toString()),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              selectedType == null
                  ? L10n.current.chooseTheCardTypeFirstThenChoose
                  : L10n.current.chooseAStoreAndScanTheCode,
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
                title: L10n.current.loyaltyCard,
                subtitle: L10n.current.addALoyaltyCardOrMembershipCard,
                onTap: () => setState(
                  () => selectedType = SmartAddManualType.loyalty,
                ),
              ),
              const SizedBox(height: 12),
              _SmartChoice(
                icon: Icons.qr_code_rounded,
                title: L10n.current.qrCode,
                subtitle: L10n.current.addOneQrCodeOrMultipleTickets,
                onTap: () => setState(
                  () => selectedType = SmartAddManualType.qr,
                ),
              ),
              const SizedBox(height: 12),
              _SmartChoice(
                icon: Icons.card_giftcard_rounded,
                title: L10n.current.giftCard,
                subtitle: L10n.current.addAGiftCardWithAnOptional,
                onTap: () => setState(
                  () => selectedType = SmartAddManualType.gift,
                ),
              ),
            ] else ...[
              _SmartChoice(
                icon: Icons.qr_code_scanner_rounded,
                title: L10n.current.chooseAStoreOrEnterManually,
                subtitle: selectedType == SmartAddManualType.qr
                    ? L10n.current.scanTheQrCodeOrEnterThe
                    : L10n.current.chooseAStoreScanTheBarcodeOr604,
                onTap: () => manual(selectedType!),
              ),
              const SizedBox(height: 12),
              _SmartChoice(
                icon: Icons.photo_library_rounded,
                title: L10n.current.importFromScreenshot,
                subtitle: L10n.current.chooseAnImageFromYourPhotoLibrary,
                onTap: analyzing ? null : () => analyze(ImageSource.gallery),
              ),
            ],
            if (analyzing) ...[
              const SizedBox(height: 18),
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFD51B46)),
              ),
              const SizedBox(height: 8),
               Center(child: Text(L10n.current.recognisingCard)),
            ],
            if (selectedType != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: analyzing
                    ? null
                    : () => setState(() => selectedType = null),
                icon: const Icon(Icons.arrow_back_rounded),
                label:  Text(L10n.current.chooseAnotherType),
              ),
            ],
            const SizedBox(height: 22),
             Row(
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
                    L10n.current.recognitionHappensOnYourDeviceYourPhoto,
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
    L10n.watch(context);
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
