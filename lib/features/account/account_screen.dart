import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/account_service.dart';
import '../../data/services/supabase_service.dart';
import '../../data/services/gift_card_share_service.dart';
import 'account_management_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  StreamSubscription<AuthState>? _authSubscription;
  PlusStatus _plusStatus = PlusStatus.inactive;
  bool _registering = false;
  bool _busy = false;
  bool _loadingStatus = false;
  bool _hidePassword = true;
  bool _isAdmin = false;

  User? get _user => AccountService.currentUser;

  @override
  void initState() {
    super.initState();
    _authSubscription = AccountService.authChanges?.listen((_) {
      if (!mounted) return;
      setState(() {});
      _loadPlusStatus();
      _loadAdminStatus();
    });
    _loadPlusStatus();
    _loadAdminStatus();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPlusStatus() async {
    if (_user == null) {
      if (mounted) setState(() => _plusStatus = PlusStatus.inactive);
      return;
    }

    setState(() => _loadingStatus = true);
    try {
      final status = await AccountService.loadPlusStatus();
      if (mounted) setState(() => _plusStatus = status);
    } catch (_) {
      // Account access still works when the status cannot be refreshed.
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _loadAdminStatus() async {
    if (_user == null) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }
    try {
      final isAdmin = await AccountService.isCurrentUserAdmin();
      if (mounted) setState(() => _isAdmin = isAdmin);
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'Vul een geldig e-mailadres in.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) {
      return 'Gebruik minimaal 8 tekens.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _busy) return;

    setState(() => _busy = true);
    try {
      if (_registering) {
        final response = await AccountService.signUp(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        if (response.session == null) {
          _showMessage(
            'Je account is aangemaakt. Controleer je e-mail om je account te bevestigen.',
          );
        } else {
          _showMessage('Welkom bij PasKluis!');
        }
      } else {
        await AccountService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        try {
          await GiftCardShareService.syncIncomingToLocal();
        } catch (_) {
          // Inloggen blijft bruikbaar als delen tijdelijk niet beschikbaar is.
        }
        if (mounted) _showMessage('Je bent ingelogd.');
      }
      _passwordController.clear();
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message), error: true);
    } catch (_) {
      if (mounted) {
        _showMessage('Dat ging niet goed. Probeer het later opnieuw.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await AccountService.signOut();
      if (mounted) _showMessage('Je bent uitgelogd.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'Het e-mailadres of wachtwoord klopt niet.';
    }
    if (normalized.contains('already registered')) {
      return 'Er bestaat al een account met dit e-mailadres.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Bevestig eerst je e-mailadres via de ontvangen e-mail.';
    }
    if (normalized.contains('password')) {
      return 'Het wachtwoord voldoet niet aan de beveiligingseisen.';
    }
    return message;
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('Account & PasKluis Plus'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
      ),
      body: !SupabaseService.isAvailable
          ? const _OfflineAccountCard()
          : _user == null
          ? _buildSignedOut()
          : _buildSignedIn(),
    );
  }

  Widget _buildSignedOut() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _PlusHero(),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _registering ? 'Account aanmaken' : 'Inloggen',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _registering
                        ? 'Je kaarten blijven veilig op dit apparaat staan.'
                        : 'Bekijk je Plus-status en neem contact op met de klantenservice.',
                  ),
                  if (_registering) ...[
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Naam',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Vul je naam in.'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'E-mailadres',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Wachtwoord',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _hidePassword = !_hidePassword,
                        ),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _registering
                                ? Icons.person_add_alt_1_rounded
                                : Icons.login_rounded,
                          ),
                    label: Text(
                      _registering ? 'Account aanmaken' : 'Inloggen',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _registering = !_registering),
                    child: Text(
                      _registering
                          ? 'Ik heb al een account'
                          : 'Nog geen account? Maak er één aan',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedIn() {
    final user = _user!;
    final name = user.userMetadata?['name']?.toString().trim();
    return RefreshIndicator(
      onRefresh: _loadPlusStatus,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFFFE7ED),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFFD51B46),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name?.isNotEmpty == true ? name! : 'PasKluis-account',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(user.email ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _StatusCard(status: _plusStatus, loading: _loadingStatus),
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: const Color(0xFFFFEDF2),
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFFD51B46),
                ),
                title: const Text(
                  'Accounts en Plus beheren',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Activeer of deactiveer PasKluis Plus voor gebruikers.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountManagementScreen(),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text(
                'Je kaarten blijven lokaal',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Inloggen verplaatst je kaarten, barcodes en pincodes niet naar de cloud.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Uitloggen'),
          ),
        ],
      ),
    );
  }
}

class _PlusHero extends StatelessWidget {
  const _PlusHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD51B46), Color(0xFFFF5577)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 38),
          SizedBox(height: 12),
          Text(
            'PasKluis Plus',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Bewaar onbeperkt cadeaukaarten voor eenmalig € 1,99. Geen abonnement en geen reclame.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final PlusStatus status;
  final bool loading;

  const _StatusCard({required this.status, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: status.isActive
          ? const Color(0xFFFFF6D8)
          : const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: status.isActive
              ? const Color(0xFFD5A021)
              : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              status.isActive
                  ? Icons.workspace_premium_rounded
                  : Icons.workspace_premium_outlined,
              color: status.isActive
                  ? const Color(0xFFD5A021)
                  : const Color(0xFFD51B46),
              size: 34,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loading
                        ? 'Plus-status controleren…'
                        : status.isActive
                        ? 'PasKluis Plus is actief'
                        : 'Gratis versie',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: status.isActive
                          ? const Color(0xFF8A6500)
                          : const Color(0xFF26252C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.isActive
                        ? status.expiresAt == null
                              ? 'Je hebt onbeperkt toegang.${_source(status.source)}'
                              : 'Je toegang is actief tot ${_date(status.expiresAt!)}.'
                        : 'Eén cadeaukaart is gratis. Klantenkaarten en QR-codes blijven onbeperkt gratis.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';

  static String _source(String? source) {
    if (source == 'complimentary') return ' Handmatig geactiveerd via beheer.';
    if (source == 'apple') return ' Geactiveerd via Apple.';
    if (source == 'google') return ' Geactiveerd via Google Play.';
    return '';
  }
}

class _OfflineAccountCard extends StatelessWidget {
  const _OfflineAccountCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48),
                SizedBox(height: 14),
                Text(
                  'Account tijdelijk niet beschikbaar',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Controleer je internetverbinding. Je lokale kaarten blijven gewoon werken.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
