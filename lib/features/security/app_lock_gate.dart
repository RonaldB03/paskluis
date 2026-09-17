import 'package:flutter/material.dart';

import '../../data/services/security_service.dart';
import '../../data/services/settings_service.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _unlocked = !SettingsService.appLockEnabled;
  bool _authenticating = false;
  bool _privacyCover = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      setState(() {
        _privacyCover = true;
        if (SettingsService.appLockEnabled) _unlocked = false;
      });
      return;
    }

    if (state == AppLifecycleState.resumed) {
      setState(() => _privacyCover = false);
      if (SettingsService.appLockEnabled && !_unlocked) {
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final success = await SecurityService.authenticate(
      reason: 'Ontgrendel PasKluis',
    );
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _unlocked = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_privacyCover) {
      return const ColoredBox(color: Color(0xFFF4F4F6));
    }

    if (_unlocked || !SettingsService.appLockEnabled) return widget.child;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 72,
                  color: Color(0xFFD51B46),
                ),
                const SizedBox(height: 20),
                const Text(
                  'PasKluis is vergrendeld',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Gebruik je biometrie of toestelcode om je kaarten te openen.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _unlock,
                  icon: _authenticating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint_rounded),
                  label: const Text('Ontgrendelen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
