import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/home/home_screen.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';
import 'data/services/settings_service.dart';
import 'data/services/supabase_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/card_share_service.dart';
import 'features/security/app_lock_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PasKluisBootstrap());
}

class PasKluisBootstrap extends StatefulWidget {
  const PasKluisBootstrap({super.key});

  @override
  State<PasKluisBootstrap> createState() => _PasKluisBootstrapState();
}

class _PasKluisBootstrapState extends State<PasKluisBootstrap>
    with WidgetsBindingObserver {
  late Future<void> _initialization;
  bool _syncingSharedCards = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialization = _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSharedCards();
    }
  }

  Future<void> _syncSharedCards() async {
    if (_syncingSharedCards) return;
    _syncingSharedCards = true;
    try {
      await CardShareService.syncAllToLocal();
    } catch (_) {
      // The local vault remains available while the account is offline.
    } finally {
      _syncingSharedCards = false;
    }
  }

  Future<void> _initialize() async {
    await SettingsService.init();
    await StorageService.init();
    await NotificationService.init();
    await SupabaseService.init();
    await SettingsService.refreshRemoteConfig();
    for (final item in StorageService.cardsBox.values.whereType<Map>()) {
      await NotificationService.syncGiftCard(item);
    }
    try {
      await CardShareService.syncAllToLocal();
    } catch (_) {
      // Sharing is optional; offline or an unavailable backend may never
      // prevent access to cards stored on this device.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.extraClearNotifier,
      builder: (context, extraClear, _) => MaterialApp(
        title: 'PasKluis',
        debugShowCheckedModeBanner: false,
        locale: const Locale('nl', 'NL'),
        supportedLocales: const [Locale('nl', 'NL')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme.copyWith(
          dividerTheme: extraClear
              ? const DividerThemeData(color: Color(0xFF303036), thickness: 1)
              : null,
        ),
        builder: (context, child) {
          if (!extraClear || child == null) return child ?? const SizedBox();
          final media = MediaQuery.of(context);
          final systemScale = media.textScaler.scale(1);
          final scale = (systemScale * 1.18).clamp(1.18, 1.6).toDouble();
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(scale),
              highContrast: true,
            ),
            child: child,
          );
        },
        home: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _StartupError(
              onRetry: () => setState(() => _initialization = _initialize()),
            );
          }
          return const AppLockGate(child: HomeScreen());
        },
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final VoidCallback onRetry;

  const _StartupError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_reset_rounded, size: 64),
                const SizedBox(height: 18),
                const Text(
                  'PasKluis kon je beveiligde opslag niet openen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Je gegevens zijn niet verwijderd. Probeer het opnieuw of herstart je apparaat.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Opnieuw proberen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
