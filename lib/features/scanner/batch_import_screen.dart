import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/card_duplicates.dart';
import '../../data/services/locale_service.dart';
import '../../data/services/smart_card_import_service.dart';
import '../../data/services/storage_service.dart';

class BatchImportScreen extends StatefulWidget {
  const BatchImportScreen({super.key});
  @override
  State<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends State<BatchImportScreen> {
  final List<SmartCardImportResult> results = [];
  final Set<int> selected = {};
  bool busy = false;
  int completed = 0, total = 0, failed = 0;
  String t(String nl, String en) =>
      LocaleService.languageCode == 'nl' ? nl : en;
  Future<void> pick() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final images = await ImagePicker().pickMultiImage(
        imageQuality: 100,
        requestFullMetadata: false,
      );
      if (!mounted) return;
      setState(() {
        results.clear();
        selected.clear();
        completed = 0;
        failed = 0;
        total = images.length;
      });
      for (final image in images) {
        if (!mounted) return;
        try {
          final result = await SmartCardImportService.analyzeImage(image.path);
          if (!mounted) return;
          final duplicate =
              result.code.isEmpty ||
              CardDuplicates.find(StorageService.cardsBox.values, {
                'code': result.code,
              }).isNotEmpty ||
              results.any((r) => r.code == result.code);
          setState(() {
            results.add(result);
            if (!duplicate) selected.add(results.length - 1);
          });
        } catch (_) {
          if (mounted) setState(() => failed++);
        }
        if (mounted) setState(() => completed++);
      }
    } catch (_) {
      if (mounted) setState(() => failed++);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(t('Screenshots importeren', 'Import screenshots')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t(
            'Je controleert en bewaart iedere geselecteerde kaart apart. Bestaande en dubbele codes worden niet automatisch geselecteerd.',
            'Review and save each selected card separately. Existing and duplicate codes are not automatically selected.',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: busy ? null : pick,
          child: Text(t('Kies afbeeldingen', 'Choose images')),
        ),
        if (busy) ...[
          const LinearProgressIndicator(),
          Text('$completed / $total'),
        ],
        if (failed > 0)
          Text(
            t(
              '$failed afbeeldingen konden niet worden gelezen. Probeer ze opnieuw of voer de kaart handmatig in.',
              '$failed images could not be read. Retry them or enter the card manually.',
            ),
          ),
        for (var i = 0; i < results.length; i++)
          CheckboxListTile(
            value: selected.contains(i),
            onChanged: busy
                ? null
                : (value) => setState(() {
                    if (value == true)
                      selected.add(i);
                    else
                      selected.remove(i);
                  }),
            title: Text(
              results[i].name.isEmpty
                  ? t('Kaart ${i + 1}', 'Card ${i + 1}')
                  : results[i].name,
            ),
            subtitle: Text(
              results[i].code.isEmpty
                  ? t(
                      'Geen code herkend; controleer handmatig',
                      'No code recognised; check manually',
                    )
                  : results[i].type,
            ),
          ),
        if (results.isNotEmpty)
          FilledButton(
            onPressed: busy || selected.isEmpty
                ? null
                : () => Navigator.pop(context, [
                    for (var i = 0; i < results.length; i++)
                      if (selected.contains(i)) results[i],
                  ]),
            child: Text(
              t(
                'Controleer ${selected.length} kaarten',
                'Review ${selected.length} cards',
              ),
            ),
          ),
      ],
    ),
  );
}
