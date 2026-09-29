import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/locale_service.dart';
import '../../data/services/terms_document.dart';
import '../../data/services/terms_service.dart';

class TermsGate extends StatelessWidget {
  final Widget child;
  const TermsGate({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: TermsService.revision,
    builder: (context, _, _) => TermsService.accepted ? child :
      TermsAcceptanceScreen(key: ValueKey(TermsService.owner)),
  );
}

class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({super.key});
  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  late final String _owner = TermsService.owner;
  late Future<String> _document;
  bool _checked = false, _saving = false;
  String? _error;
  bool get _nl => LocaleService.languageCode == 'nl';
  String t(String nl, String en) => _nl ? nl : en;
  @override
  void initState() { super.initState(); _document = _load(); }
  Future<String> _load() async {
    final raw = await rootBundle.loadString('assets/config/terms.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != TermsDocument.version) throw StateError('Wrong version');
    return data[_nl ? 'nl' : 'en'] as String;
  }
  Future<void> _accept() async {
    setState(() { _saving = true; _error = null; });
    try {
      await TermsService.accept(_owner, _nl ? 'nl' : 'en');
      unawaited(TermsService.sync());
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = t('Opslaan is niet gelukt. Probeer opnieuw.', 'Could not save. Please try again.'); });
    }
  }
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(title: Text(t('Gebruiksvoorwaarden', 'Terms of use'))),
      body: SafeArea(child: FutureBuilder<String>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: TextButton(
            onPressed: () => setState(() { _document = _load(); }),
            child: Text(t('Opnieuw proberen', 'Try again'))));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text(t('Duidelijke afspraken over jouw kaarten', 'Clear agreements about your cards'),
              style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(t('Lees de voorwaarden hieronder. Je bestaande kaarten worden niet verwijderd. Zonder akkoord kun je de app sluiten of contact opnemen via info@paskluis.com voor hulp bij je gegevens.',
              'Read the terms below. Your existing cards will not be deleted. If you disagree, close the app or contact info@paskluis.com for help with your data.')),
            const SizedBox(height: 20),
            SelectableText(snapshot.data!, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 12),
            Builder(builder: (shareContext) => TextButton.icon(
              icon: const Icon(Icons.share_outlined),
              label: Text(t('Voorwaarden bewaren of delen', 'Save or share terms')),
              onPressed: () async {
                final box = shareContext.findRenderObject() as RenderBox?;
                try {
                  await SharePlus.instance.share(ShareParams(text: snapshot.data!,
                    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size));
                } catch (_) { /* The document remains selectable and readable. */ }
              },
            )),
            CheckboxListTile(contentPadding: EdgeInsets.zero,
              value: _checked,
              onChanged: _saving ? null : (value) => setState(() => _checked = value ?? false),
              title: Text(t('Ik ga akkoord met de gebruiksvoorwaarden, versie ${TermsDocument.version}.',
                'I agree to the terms of use, version ${TermsDocument.version}.'))),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(onPressed: _checked && !_saving ? _accept : null,
              child: Text(t('Akkoord en doorgaan', 'Agree and continue'))),
          ]);
        },
      )),
    ),
  );
}
