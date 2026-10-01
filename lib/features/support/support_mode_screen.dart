import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/account_service.dart';
import '../../data/services/support_mode_service.dart';
import '../../data/services/managed_content_service.dart';

class SupportModeScreen extends StatefulWidget {
  const SupportModeScreen({super.key});

  @override
  State<SupportModeScreen> createState() => _SupportModeScreenState();
}

class _SupportModeScreenState extends State<SupportModeScreen> {
  SupportModeSession? _session;
  bool _busy = false;
  String? _error;
  Timer? _timer;

  bool get _nl => Localizations.localeOf(context).languageCode == 'nl';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (AccountService.currentUser == null) {
      setState(
        () => _error = _nl
            ? 'Log eerst in om de veilige Supportmodus te gebruiken.'
            : 'Sign in first to use Secure Support Mode.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await SupportModeService.create();
      if (!mounted) return;
      setState(() => _session = session);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = _nl
              ? 'Supportmodus kon niet worden gestart. Controleer je verbinding en probeer opnieuw.'
              : 'Support Mode could not be started. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      await SupportModeService.revoke(session.id);
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = _nl
              ? 'Intrekken is niet gelukt. Controleer je verbinding en probeer opnieuw.'
              : 'Could not revoke access. Check your connection and try again.';
        });
      return;
    }
    if (mounted)
      setState(() {
        _session = null;
        _busy = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final language = _nl ? 'nl' : 'en';
    final remaining = _session?.codeExpiresAt.difference(DateTime.now());
    final valid = remaining != null && !remaining.isNegative;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F6),
      appBar: AppBar(
        title: ValueListenableBuilder<int>(
          valueListenable: ManagedContentService.revision,
          builder: (_, __, ___) => Text(
            ManagedContentService.text(
              'supportMode.title',
              language,
              _nl ? 'Veilige Supportmodus' : 'Secure Support Mode',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 42,
                    color: Color(0xFFD51B46),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _nl ? 'Jij houdt de controle' : 'You stay in control',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _nl
                        ? 'Met jouw tijdelijke code kan een bevoegde medewerker maximaal 30 minuten je technische instellingen bekijken en aanpassen. Je kunt de toegang altijd intrekken.'
                        : 'Your temporary code lets an authorised employee view and change your technical settings for up to 30 minutes. You can revoke access at any time.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            color: const Color(0xFFFFF4F7),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nl
                        ? 'Nooit zichtbaar voor klantenservice'
                        : 'Never visible to support',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nl
                        ? 'Kaartcodes, kaartnummers, barcodes, QR-codes, pincodes, afbeeldingen, wachtwoorden, betaalgegevens en je exacte locatie of locatiegeschiedenis.'
                        : 'Card codes, card numbers, barcodes, QR codes, PINs, images, passwords, payment details and your exact location or location history.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_session != null)
            ValueListenableBuilder<String>(
              valueListenable: SupportModeService.status,
              builder: (_, status, __) => Text(
                status == 'active'
                    ? (_nl
                          ? 'Support is verbonden. Je kunt de toegang hieronder intrekken.'
                          : 'Support is connected. You can revoke access below.')
                    : status == 'ended'
                    ? (_nl ? 'De toegang is beëindigd.' : 'Access has ended.')
                    : '',
                textAlign: TextAlign.center,
              ),
            ),
          if (_session != null && valid) ...[
            Text(
              _nl
                  ? 'Geef deze eenmalige code door:'
                  : 'Share this one-time code:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              _session!.code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 9,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _session!.code));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_nl ? 'Code gekopieerd' : 'Code copied'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(_nl ? 'Code kopiëren' : 'Copy code'),
            ),
            const SizedBox(height: 6),
            Text(
              _nl
                  ? 'Code verloopt over ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'
                  : 'Code expires in ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _revoke,
              icon: const Icon(Icons.block),
              label: Text(_nl ? 'Toegang intrekken' : 'Revoke access'),
            ),
          ] else ...[
            if (_session != null && SupportModeService.status.value != 'ended')
              OutlinedButton.icon(
                onPressed: _busy ? null : _revoke,
                icon: const Icon(Icons.block),
                label: Text(_nl ? 'Toegang intrekken' : 'Revoke access'),
              ),
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_clock_outlined),
              label: Text(
                _nl ? 'Tijdelijke code maken' : 'Create temporary code',
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
