import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/card_screen_session.dart';
import 'package:paskluis_v1/data/services/settings_service.dart';
import 'package:paskluis_v1/features/qr_codes/qr_codes_screen.dart';

void main() {
  for (final enabled in [true, false]) {
    testWidgets('QR brightness preference=$enabled restores after pause and close', (tester) async {
      SharedPreferences.setMockInitialValues({'auto_brightness': enabled, 'keep_screen_awake': false});
      await SettingsService.init();
      await SettingsService.setAutoBrightnessEnabled(enabled);
      final calls = <String>[];
      final controller = CardScreenController(
        brighten: () async { calls.add('max'); },
        reset: () async { calls.add('restore'); },
        wake: () async {}, sleep: () async {},
      );
      await tester.pumpWidget(MaterialApp(home: QrCodeViewScreen(
        screenController: controller,
        // No stored ID: displaying this fixture must not mutate the vault.
        items: [{'name': 'Test', 'code': '123456', 'type': 'QR-code'}], initialIndex: 0,
      )));
      await tester.pumpAndSettle();
      expect(calls, enabled ? ['max'] : isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(calls, enabled ? ['max', 'restore'] : isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(calls, enabled ? ['max', 'restore', 'max', 'restore'] : isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
