import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/locale_service.dart';
import 'package:paskluis_v1/data/services/settings_service.dart';
import 'package:paskluis_v1/features/security/app_lock_gate.dart';
import 'package:paskluis_v1/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('privacy cover hides pushed routes and retains navigation state', (tester) async {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
    await SettingsService.init();
    await LocaleService.init();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      locale: const Locale('nl'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => AppLockGate(child: child!),
      home: const Scaffold(body: Text('Home test')),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Private conversation')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Private conversation'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Private conversation'), findsNothing);
    expect(find.text('Private conversation', skipOffstage: false), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Private conversation'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
  });
  test('version advice compares numeric components and ignores malformed config', () {
    expect(SettingsService.versionIsOlder('1.5.0','1.10.0'), isTrue);
    expect(SettingsService.versionIsOlder('1.5.0','1.5.0'), isFalse);
    expect(SettingsService.versionIsOlder('1.5.0','1.4.99'), isFalse);
    expect(SettingsService.versionIsOlder('1.5.0','invalid'), isFalse);
  });
}
