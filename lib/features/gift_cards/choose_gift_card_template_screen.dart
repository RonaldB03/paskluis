import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/smart_card_import_service.dart';
import 'add_gift_card_screen.dart';

class ChooseGiftCardTemplateScreen extends StatefulWidget {
  const ChooseGiftCardTemplateScreen({super.key});

  @override
  State<ChooseGiftCardTemplateScreen> createState() =>
      _ChooseGiftCardTemplateScreenState();
}

class _ChooseGiftCardTemplateScreenState
    extends State<ChooseGiftCardTemplateScreen> {
  Future<void> openCustomGiftCard() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const AddGiftCardScreen()),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  Future<void> startAutomaticImport(ImageSource source) async {
    SmartCardImportResult? scan;
    try {
      scan = await SmartCardImportService.pickAndAnalyze(source: source);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(L10n.current.thePhotoCouldNotBeReadPlease)),
        );
      }
      return;
    }
    if (!mounted || scan == null) return;
    final importResult = scan;
    if (importResult.code.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(L10n.current.noCodeFoundTryAClearerPhoto),
        ),
      );
      return;
    }

    final brand = importResult.brand;
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddGiftCardScreen(
          initialName: brand == null ? null : L10n.current.giftCard((brand.name).toString()),
          initialCode: importResult.code.trim(),
          initialCodeFormat: importResult.codeFormat,
          initialBarcodeSymbology: importResult.barcodeSymbology,
          initialPinCode: importResult.pinCode,
          initialCurrentBalance: importResult.balance,
          initialExpiryDate: importResult.expiryDate,
          initialCardNumber: importResult.code.trim(),
          initialBrandId: brand?.id,
          initialLogoAsset: brand?.logoAsset,
          initialBrandColor: brand?.color.value.toString(),
          initialLogoLayout: brand?.logoLayout ?? const {},
        ),
      ),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
        foregroundColor: const Color(0xFF303036),
        centerTitle: true,
        title:  Text(
          L10n.current.addGiftCard,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          const Icon(
            Icons.document_scanner_rounded,
            size: 72,
            color: Color(0xFFD51B46),
          ),
          const SizedBox(height: 20),
           Text(
            L10n.current.photographTheWholeGiftCard,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF303036),
            ),
          ),
          const SizedBox(height: 12),
           Text(
            L10n.current.makeSureTheCodeAndAnyPin,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.45, color: Colors.black54),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: () => startAutomaticImport(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label:  Text(L10n.current.takeAPhoto),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD51B46),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => startAutomaticImport(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label:  Text(L10n.current.choosePhotoOrScreenshot),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD51B46),
                side: const BorderSide(color: Color(0xFFD51B46)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: openCustomGiftCard,
            icon: const Icon(Icons.edit_outlined),
            label:  Text(L10n.current.addManually),
            style: TextButton.styleFrom(foregroundColor: Colors.black54),
          ),
          const SizedBox(height: 22),
           Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: Colors.black38),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  L10n.current.recognitionHappensOnYourDeviceYourPhoto,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
