import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/account_service.dart';
import '../../data/services/supabase_service.dart';
import '../../data/services/card_share_service.dart';
import '../../data/services/device_session_service.dart';
import '../../data/services/push_notification_service.dart';
import '../premium/plus_information_screen.dart';
import 'shared_cards_management_screen.dart';
import 'delete_account_screen.dart';
import '../../data/services/purchase_service.dart';
import '../../data/services/settings_service.dart';

class AccountScreen extends StatefulWidget {
  final bool startPasswordRecovery;

  const AccountScreen({
    super.key,
    this.startPasswordRecovery = false,
  });

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
  bool _handlingPasswordRecovery = false;

  User? get _user => AccountService.currentUser;

  @override
  void initState() {
    super.initState();
    _authSubscription = AccountService.authChanges?.listen((_) {
      if (!mounted) return;
      setState(() {});
      _loadPlusStatus();
    });
    _loadPlusStatus();
    PurchaseService.revision.addListener(_purchaseChanged);
    unawaited(PurchaseService.loadProduct().catchError((_) {}));
    if (widget.startPasswordRecovery) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _finishPasswordRecovery(),
      );
    }
  }

  @override
  void dispose() {
    PurchaseService.revision.removeListener(_purchaseChanged);
    _authSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _purchaseChanged() {
    if(!mounted)return;
    setState(() {});
    if(PurchaseService.messageCode=='success') unawaited(_loadPlusStatus());
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

  Future<void> _restorePurchases() async {
    if(_user==null){_showMessage(L10n.current.signInToRestoreYourPurchase);return;}
    try{
      await PurchaseService.restore();
      await _loadPlusStatus();
      if(mounted)_showMessage(L10n.current.restoreRequested);
    }catch(_){if(mounted)_showMessage(L10n.current.unableToRestoreYourPurchaseRightNow,error:true);}
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return L10n.current.enterAValidEmailAddress;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) {
      return L10n.current.useAtLeast8Characters;
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _busy) return;

    setState(() => _busy = true);
    DeviceSessionService.awaitingClaim = true;
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
            L10n.current.yourAccountHasBeenCreatedCheckYour,
          );
        } else {
          if (!await _activateDeviceSession()) return;
          _showMessage(L10n.current.welcomeToPaskluis);
        }
      } else {
        await AccountService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!await _activateDeviceSession()) return;
        await PushNotificationService.registerForCurrentUser();
        try {
          await CardShareService.syncAllToLocal();
        } catch (_) {
          // Inloggen blijft bruikbaar als delen tijdelijk niet beschikbaar is.
        }
        if (mounted) _showMessage(L10n.current.youAreSignedIn);
      }
      await _loadPlusStatus();
      _passwordController.clear();
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message), error: true);
    } catch (_) {
      if (mounted) {
        _showMessage(L10n.current.somethingWentWrongPleaseTryAgainLater, error: true);
      }
    } finally {
      DeviceSessionService.awaitingClaim = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      _showMessage(emailError, error: true);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AccountService.resetPassword(_emailController.text);
      if (mounted) {
        _showMessage(
          L10n.current.ifThisEmailAddressIsRegisteredWith,
        );
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message), error: true);
    } catch (_) {
      if (mounted) {
        _showMessage(L10n.current.thePasswordResetEmailCouldNotBe, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishPasswordRecovery() async {
    if (!mounted || _handlingPasswordRecovery) return;
    _handlingPasswordRecovery = true;
    try {
      final password = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (_) => const _ChangePasswordSheet(),
      );
      if (password == null || !mounted) return;
      await AccountService.updatePassword(password);
      await _activateDeviceSession();
      await PushNotificationService.registerForCurrentUser();
      if (mounted) _showMessage(L10n.current.yourNewPasswordHasBeenSaved);
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message), error: true);
    } catch (_) {
      if (mounted) {
        _showMessage(L10n.current.unableToChangeYourPassword, error: true);
      }
    } finally {
      _handlingPasswordRecovery = false;
      DeviceSessionService.awaitingClaim = false;
    }
  }

  Future<bool> _activateDeviceSession() async {
    final status = await DeviceSessionService.inspect();
    if (!status.hasActiveDevice || status.isCurrentDevice) {
      return DeviceSessionService.claim();
    }
    if (!mounted) return false;

    final replace = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.devices_rounded, size: 42),
        title:  Text(L10n.current.alreadySignedInOnAnotherDevice),
        content: Text(
          L10n.current.thisAccountIsActiveOnIfYou((status.activeDeviceName.isEmpty ? L10n.current.anotherDevice151 : status.activeDeviceName).toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:  Text(L10n.current.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child:  Text(L10n.current.signInHere),
          ),
        ],
      ),
    );

    if (replace != true) {
      await AccountService.signOut(releaseDevice: false);
      return false;
    }
    return DeviceSessionService.claim(replace: true);
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await AccountService.signOut();
      if (mounted) _showMessage(L10n.current.youHaveBeenSignedOut);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (password == null || !mounted || _busy) return;

    setState(() => _busy = true);
    try {
      await AccountService.updatePassword(password);
      if (mounted) _showMessage(L10n.current.yourPasswordHasBeenChanged);
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message), error: true);
    } catch (_) {
      if (mounted) {
        _showMessage(L10n.current.unableToChangeYourPassword, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return L10n.current.theEmailAddressOrPasswordIsIncorrect;
    }
    if (normalized.contains('already registered')) {
      return L10n.current.anAccountWithThisEmailAddressAlready;
    }
    if (normalized.contains('email not confirmed')) {
      return L10n.current.confirmYourEmailAddressUsingTheEmail;
    }
    if (normalized.contains('password')) {
      return L10n.current.thePasswordDoesNotMeetTheSecurity;
    }
    return L10n.current.pleaseTryAgain;
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
    L10n.watch(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title:  Text(L10n.current.accountPaskluisPlus),
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
    final sessionNotice = DeviceSessionService.sessionNotice.value;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (sessionNotice != null) ...[
          Card(
            color: const Color(0xFFFFF3CD),
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded),
              title:  Text(
                L10n.current.signedOutOnThisDevice,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(sessionNotice),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
                    _registering ? L10n.current.createAccount : L10n.current.signIn,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _registering
                        ? L10n.current.yourCardsStaySafelyOnThisDevice
                        : L10n.current.checkYourPlusStatusAndContactCustomer,
                  ),
                  if (_registering) ...[
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration:  InputDecoration(
                        labelText: L10n.current.name,
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? L10n.current.enterYourName
                          : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration:  InputDecoration(
                      labelText: L10n.current.emailAddress,
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
                      labelText: L10n.current.password,
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
                  if (!_registering)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child:  Text(L10n.current.forgotPassword),
                      ),
                    )
                  else
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
                      _registering ? L10n.current.createAccount : L10n.current.signIn,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _registering = !_registering),
                    child: Text(
                      _registering
                          ? L10n.current.iAlreadyHaveAnAccount
                          : L10n.current.noAccountYetCreateOne,
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
                          name?.isNotEmpty == true ? name! : L10n.current.paskluisAccount,
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
          if(!_plusStatus.isActive) ...[
            const SizedBox(height:12),
            FilledButton.icon(
              style:FilledButton.styleFrom(backgroundColor:const Color(0xFFD5A021)),
              onPressed:PurchaseService.busy||PurchaseService.product==null||!SettingsService.storePurchaseEnabled?null:PurchaseService.buy,
              icon:const Icon(Icons.workspace_premium),
              label:Text(PurchaseService.busy?L10n.current.purchaseProcessing:'${L10n.current.buyPlus} · ${PurchaseService.product?.price??'€ 1,99'}'),
            ),
            if(PurchaseService.product==null||!SettingsService.storePurchaseEnabled)
              Text(L10n.current.storePurchaseUnavailable,textAlign:TextAlign.center),
          ],
          if(PurchaseService.messageCode!=null)
            Padding(padding:const EdgeInsets.all(12),child:Text(switch(PurchaseService.messageCode){
              'success'=>L10n.current.purchaseSucceeded,
              'pending'=>L10n.current.purchasePending,
              'cancelled'=>L10n.current.purchaseCancelled,
              'signIn'=>L10n.current.signInToRestoreYourPurchase,
              'verification'=>L10n.current.purchaseVerificationPending,
              _=>L10n.current.purchaseFailed,
            },textAlign:TextAlign.center)),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFFD5A021)),
              title:  Text(L10n.current.allAboutPaskluisPlus,
                  style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle:  Text(L10n.current.exploreAllBenefitsAndLearnHowSharing),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PlusInformationScreen(
                    showAccountButton: false,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.people_alt_outlined,
                  color: Color(0xFF7046B8)),
              title:  Text(L10n.current.manageSharedCards,
                  style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle:  Text(L10n.current.viewSharedAccessAndStopItWhenever),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SharedCardsManagementScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.restore_rounded,
                  color: Color(0xFF286DC8)),
              title:  Text(L10n.current.restorePurchases,
                  style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle:  Text(L10n.current.checkYourLinkedPlusAccessAgain),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _loadingStatus || PurchaseService.busy ? null : _restorePurchases,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(
                Icons.password_rounded,
                color: Color(0xFFD51B46),
              ),
              title:  Text(
                L10n.current.changePassword,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle:  Text(
                L10n.current.chooseANewPasswordWithAtLeast,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _busy ? null : _changePassword,
            ),
          ),
          const SizedBox(height: 16),
           Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text(
                L10n.current.yourCardsStayLocal,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                L10n.current.signingInDoesNotMoveYourCards,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.person_remove_outlined, color: Color(0xFFD51B46)),
            title: Text(L10n.current.deleteAccount), trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountScreen()))),
          OutlinedButton.icon(
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label:  Text(L10n.current.signOut),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    Navigator.pop(context, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Text(
                L10n.current.changePassword,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
               Text(
                L10n.current.useAtLeast8CharactersYouWill,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                autofocus: true,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: L10n.current.newPassword,
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
                validator: (value) => (value ?? '').length < 8
                    ? L10n.current.useAtLeast8Characters
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmationController,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration:  InputDecoration(
                  labelText: L10n.current.repeatNewPassword,
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value != _passwordController.text
                    ? L10n.current.thePasswordsDoNotMatch
                    : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label:  Text(L10n.current.savePassword),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusHero extends StatelessWidget {
  const _PlusHero();

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B4A00), Color(0xFFD5A021)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child:  Column(
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
            L10n.current.storeUnlimitedGiftCardsAndShareCards,
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
    L10n.watch(context);
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
                        ? L10n.current.checkingPlusStatus
                        : status.isActive
                        ? L10n.current.paskluisPlusIsActive
                        : L10n.current.freeVersion,
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
                              ? L10n.current.youHaveUnlimitedAccess((_source(status.source)).toString())
                              : L10n.current.yourAccessIsActiveUntil((_date(status.expiresAt!)).toString())
                        : L10n.current.storeOneGiftCardForFreeLoyalty,
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
    if (source == 'complimentary') return L10n.current.activatedManuallyByAnAdministrator;
    if (source == 'apple') return L10n.current.activatedThroughApple;
    if (source == 'google') return L10n.current.activatedThroughGooglePlay;
    return '';
  }
}

class _OfflineAccountCard extends StatelessWidget {
  const _OfflineAccountCard();

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return  Center(
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
                  L10n.current.accountTemporarilyUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  L10n.current.checkYourInternetConnectionYourLocalCards,
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
