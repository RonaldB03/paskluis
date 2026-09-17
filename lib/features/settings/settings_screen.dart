import 'package:flutter/material.dart';

import '../../data/services/security_service.dart';
import '../../data/services/settings_service.dart';
import '../account/account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _appLockEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _appLockEnabled = SettingsService.appLockEnabled;
  }

  Future<void> _changeAppLock(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);

    if (enabled) {
      final authenticated = await SecurityService.authenticate(
        reason: 'Bevestig je identiteit om app-vergrendeling in te schakelen',
      );
      if (!authenticated) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }

    await SettingsService.setAppLockEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _appLockEnabled = enabled;
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'App-vergrendeling is ingeschakeld.'
              : 'App-vergrendeling is uitgeschakeld.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('Instellingen'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(
                Icons.workspace_premium_outlined,
                color: Color(0xFFD51B46),
              ),
              title: const Text(
                'Account & PasKluis Plus',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Inloggen, registreren en je Plus-status bekijken.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: SwitchListTile.adaptive(
              value: _appLockEnabled,
              onChanged: _saving ? null : _changeAppLock,
              secondary: const Icon(Icons.lock_outline_rounded),
              title: const Text(
                'Vergrendel PasKluis',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Vraag biometrie of je toestelcode wanneer je de app opent.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Je kaarten, codes en pincodes worden lokaal en versleuteld op dit apparaat bewaard. Een account bewaart alleen je profiel, Plus-status en klantenserviceberichten.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('PasKluis'),
              subtitle: Text('Versie 1.2.0'),
            ),
          ),
        ],
      ),
    );
  }
}
