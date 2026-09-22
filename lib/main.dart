import 'features/support/support_thread_screen.dart';
import 'data/services/support_service.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'data/services/locale_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/home/home_screen.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';
import 'data/services/settings_service.dart';
import 'data/services/supabase_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/card_share_service.dart';
import 'data/services/account_service.dart';
import 'data/services/purchase_service.dart';
import 'data/services/device_session_service.dart';
import 'data/services/push_notification_service.dart';
import 'features/security/app_lock_gate.dart';
import 'features/account/account_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PasKluisBootstrap());
}

class PasKluisBootstrap extends StatefulWidget {
  const PasKluisBootstrap({super.key});

  @override
  State<PasKluisBootstrap> createState() => _PasKluisBootstrapState();
}

class _PasKluisBootstrapState extends State<PasKluisBootstrap>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late Future<void> _initialization;
  bool _syncingSharedCards = false;
  bool _checkingDeviceSession = false;
  Timer? _deviceSessionTimer;
  StreamSubscription<AuthState>? _authSubscription;
  bool _openingPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialization = _initialize();
    LocaleService.locale.addListener(_languageChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocaleService.locale.removeListener(_languageChanged);
    _deviceSessionTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshOnline());
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) => LocaleService.refreshSystemLocale();

  void _languageChanged() {
    if (mounted) setState(() {});
    _syncLanguage();
  }

  Future<void> _syncLanguage() async {
    try {
      await AccountService.syncLanguage();
      await PushNotificationService.syncLanguage();
      for (final card in StorageService.cardsBox.values.whereType<Map>()) {
        await NotificationService.syncGiftCard(card);
      }
    } catch (_) {
      // Device preference remains available offline; retry on app resume/sign-in.
    }
  }

  Future<void> _checkDeviceSession() async {
    if (_checkingDeviceSession || AccountService.isSigningOut || DeviceSessionService.awaitingClaim ||
        AccountService.currentUser == null) return;
    _checkingDeviceSession = true;
    try {
      final isCurrent = await DeviceSessionService.ensureCurrentSession();
      if (!isCurrent && AccountService.currentUser != null) {
        final notice =
            L10n.current.someoneSignedInToYourAccountOn;
        DeviceSessionService.sessionNotice.value = notice;
        await AccountService.signOut(releaseDevice: false);
        _showDeviceLogoutNotice(notice);
      }
    } catch (_) {
      // A temporary connection problem must not lock the local vault.
    } finally {
      _checkingDeviceSession = false;
    }
  }

  void _showDeviceLogoutNotice(String notice) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (!mounted || context == null) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.devices_rounded, size: 44),
          title:  Text(L10n.current.youHaveBeenSignedOut733),
          content: Text(notice),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:  Text(L10n.current.gotIt),
            ),
          ],
        ),
      );
    });
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

  Future<void> _registerPushToken() async {
    try {
      await PushNotificationService.registerForCurrentUser();
    } catch (_) {
      // Push is optional; cards remain available when messaging is offline.
    }
  }

  Future<void> _initialize() async {
    await StorageService.init();
    await LocaleService.init(hasSavedCards: StorageService.cardsBox.isNotEmpty);
    await SettingsService.init();
    await NotificationService.init();
    await SupabaseService.init();
    await StorageService.reconcileAccount(AccountService.currentUser?.id);
    PurchaseService.init();
    try {
      NotificationService.onOpen = (payload) async {
        if(payload.startsWith('support_reply:')) await _openSupportThread(payload.substring(14));
      };
      await PushNotificationService.init(onSharedCardChanged: _syncSharedCards, onSupportOpened: _openSupportThread);
    } catch (_) {
      // Firebase Messaging may be unavailable on an unsupported device.
    }
    _authSubscription ??= AccountService.authChanges?.listen((state) async {
      if(AccountService.isSigningOut && state.session != null) return;
      if(state.event == AuthChangeEvent.passwordRecovery) DeviceSessionService.awaitingClaim = true;
      final accountId = state.session?.user.id;
      final previousId = StorageService.accountId;
      final changed = previousId != null && previousId != accountId;
      await StorageService.reconcileAccount(accountId);
      if (changed && mounted) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _openPasswordRecovery();
      }
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed) {
        if (!DeviceSessionService.awaitingClaim) unawaited(_refreshOnline());
      }
    });
    _deviceSessionTimer ??= Timer.periodic(
      const Duration(seconds: 30), (_) => _checkDeviceSession(),
    );
    // Opening an offline vault must not wait for remote APIs.
    unawaited(_refreshOnline());
  }

  bool _refreshingOnline = false;
  Future<void> _refreshOnline() async {
    if (_refreshingOnline) return;
    _refreshingOnline = true;
    try {
      await _checkDeviceSession();
      await SettingsService.refreshRemoteConfig();
      await _registerPushToken();
      await _syncLanguage();
      await _syncSharedCards();
    } catch (_) {
      // A retry follows on resume; local cards remain usable.
    } finally {
      _refreshingOnline = false;
    }
  }

  Future<void> _openSupportThread(String id) async {
    if(id.isEmpty)return;
    try {
      final threads=await SupportService.loadThreads();
      final thread=threads.where((t)=>t.id==id).firstOrNull;
      if(thread==null || !mounted)return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) _navigatorKey.currentState?.push(MaterialPageRoute<void>(builder:(_)=>SupportThreadScreen(thread:thread)));
      });
    } catch (_) {}
  }

  void _openPasswordRecovery() {
    if (_openingPasswordRecovery) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = _navigatorKey.currentState;
      if (!mounted || navigator == null || _openingPasswordRecovery) return;
      _openingPasswordRecovery = true;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const AccountScreen(startPasswordRecovery: true),
        ),
      );
      _openingPasswordRecovery = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.extraClearNotifier,
      builder: (context, extraClear, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'PasKluis',
        debugShowCheckedModeBanner: false,
        locale: LocaleService.locale.value,
        supportedLocales: LocaleService.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
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
          Widget protectedChild = FutureBuilder<void>(
            future: _initialization,
            builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
                ? AppLockGate(child: child ?? const SizedBox())
                : child ?? const SizedBox(),
          );
          if (!extraClear || child == null) return protectedChild;
          final media = MediaQuery.of(context);
          final systemScale = media.textScaler.scale(1);
          final scale = (systemScale * 1.18).clamp(1.18, 1.6).toDouble();
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(scale),
              highContrast: true,
            ),
            child: protectedChild,
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
          return const HomeScreen();
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
    L10n.watch(context);
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
                 Text(
                  L10n.current.paskluisCouldNotOpenYourSecureStorage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                 Text(
                  L10n.current.yourDataHasNotBeenDeletedTry,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: onRetry,
                  child:  Text(L10n.current.tryAgain),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
