import '../../shared/widgets/duplicate_card_warning.dart';
import '../../data/services/barcode_image_service.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'add_qr_code_screen.dart';
import 'multi_qr_scanner_screen.dart';
import 'qr_scanner_screen.dart';

class ChooseQrCodeScreen extends StatefulWidget {
  const ChooseQrCodeScreen({super.key});

  @override
  State<ChooseQrCodeScreen> createState() => _ChooseQrCodeScreenState();
}

class _ChooseQrCodeScreenState extends State<ChooseQrCodeScreen> {
  bool _importing = false;

  Future<void> openManual(BuildContext context) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const AddQrCodeScreen()),
    );

    if (!context.mounted || result == null) return;

    Navigator.pop(context, result);
  }

  Future<void> _openCodeEditor(BuildContext context, String code) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddQrCodeScreen(initialCode: code.trim()),
      ),
    );

    if (!context.mounted || result == null) return;
    Navigator.pop(context, result);
  }

  Future<void> openScanner(BuildContext context) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (!context.mounted || code == null || code.trim().isEmpty) return;
    await _openCodeEditor(context, code);
  }

  Future<void> openMultiScanner(BuildContext context) async {
    final codes = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const MultiQrScannerScreen()),
    );

    if (!context.mounted || codes == null || codes.isEmpty) return;
    await _finishCodes(context, codes);
  }

  Future<void> importImages(BuildContext context) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final codes = <String>{};
      var failed = false;
      try {
        final images = await ImagePicker().pickMultiImage(
          imageQuality: 100,
          requestFullMetadata: false,
        );
        if (!context.mounted || images.isEmpty) return;
        for (final image in images) {
          try {
            final capture = await BarcodeImageService.analyze(
              image.path,
              formats: const [BarcodeFormat.qrCode],
            );
            for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
              if (barcode.format != BarcodeFormat.qrCode) continue;
              final value = barcode.rawValue?.trim() ?? '';
              if (value.isNotEmpty) codes.add(value);
            }
          } catch (_) {
            failed = true;
          }
        }
      } catch (_) {
        failed = true;
      }

      if (!context.mounted) return;
      if (codes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(
              failed
                  ? L10n.current.unableToReadImage
                  : L10n.current.noQrCodeFoundInTheSelected,
            ),
          ),
        );
        return;
      }
      if (codes.length == 1) {
        await _openCodeEditor(context, codes.first);
        return;
      }
      await _finishCodes(context, codes.toList());
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _finishCodes(
    BuildContext context,
    List<String> codes,
  ) async {

    final nameController = TextEditingController(
      text: L10n.current.qrCodes((codes.length).toString()),
    );

    final setName = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title:  Text(L10n.current.nameYourQrSet),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration:  InputDecoration(
              labelText: L10n.current.name,
              hintText: L10n.current.eGFestivalTickets,
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
              child:  Text(L10n.current.cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = nameController.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(context, value);
              },
              child:  Text(L10n.current.save),
            ),
          ],
        );
      },
    );

    nameController.dispose();

    if (!context.mounted || setName == null || setName.trim().isEmpty) return;

    if (!await confirmDuplicateCard(context, {'type': 'QR-set', 'codes': codes.join('|||')})) return;
    if (!mounted) return;

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
          L10n.current.addQrCode,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _importing ? null : () => openManual(context),
            child:  Text(
              L10n.current.manual,
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
           Text(
            L10n.current.howWouldYouLikeToAddYour,
            style: TextStyle(
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF303036),
            ),
          ),
          const SizedBox(height: 8),
           Text(
            L10n.current.scanOneQrCodeOrSeveralTickets,
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: Color(0xFF555557),
            ),
          ),
          const SizedBox(height: 22),
          if (_importing) const LinearProgressIndicator(),
          _QrChoiceTile(
            isDisabled: _importing,
            icon: Icons.qr_code_scanner_rounded,
            title: L10n.current.scanOneQrCode,
            subtitle: L10n.current.useYourCameraToAddAQr,
            onTap: () => openScanner(context),
          ),
          const SizedBox(height: 10),
          _QrChoiceTile(
            isDisabled: _importing,
            icon: Icons.confirmation_number_rounded,
            title: L10n.current.multipleQrCodes,
            subtitle:
                L10n.current.scanSeveralTicketsInARowAnd,
            onTap: () => openMultiScanner(context),
          ),
          const SizedBox(height: 10),
          _QrChoiceTile(
            isDisabled: _importing,
            icon: Icons.edit_note_rounded,
            title: L10n.current.enterManually,
            subtitle: L10n.current.enterANameAndQrCodeContent,
            onTap: () => openManual(context),
          ),
          const SizedBox(height: 10),
          _QrChoiceTile(
            isDisabled: _importing,
            icon: Icons.image_rounded,
            title: L10n.current.importPhotoOrScreenshot,
            subtitle: L10n.current.readOneOrMoreQrCodesFrom,
            onTap: () => importImages(context),
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
    L10n.watch(context);
    final color = isDisabled ? Colors.grey : const Color(0xFFD51B46);

    return Material(
      color: Colors.white,
      elevation: 0.8,
      shadowColor: Colors.black.withOpacity(0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isDisabled ? null : onTap,
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
