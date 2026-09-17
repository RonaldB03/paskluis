import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';
import 'data/services/settings_service.dart';
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

class _PasKluisBootstrapState extends State<PasKluisBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await SettingsService.init();
    await StorageService.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PasKluis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
