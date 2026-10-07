import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/settings_service.dart';
import 'package:paskluis_v1/data/services/locale_service.dart';
import 'package:paskluis_v1/features/gift_cards/gift_card_view_screen.dart';
import 'package:paskluis_v1/l10n/generated/app_localizations.dart';
import 'package:paskluis_v1/l10n/l10n.dart';

void main() {
  testWidgets('known expiry remains readable below the used-card action on a narrow phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    await LocaleService.init();
    await LocaleService.setLanguage('nl');
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('nl'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: MediaQuery(
        data: const MediaQueryData(size: Size(360,740),textScaler: TextScaler.linear(1.3)),
        child: GiftBarcodeCard(item: const {
          'name':'Voorbeeldwinkel', 'code':'123456789012', 'currentBalance':'25.50',
          'expiryDate':'2030-12-31', 'type':'Cadeaukaart'
        }, barcode: Barcode.code128(), onDetails: () {}, onUsed: () {}),
      )),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final expiry=find.text('Geldig t/m 31 december 2030');
    expect(expiry,findsOneWidget);
    expect(tester.getTopLeft(expiry).dy,greaterThan(tester.getBottomLeft(find.text(L10n.current.usedThisCard)).dy));
    expect(tester.getBottomRight(expiry).dx,lessThanOrEqualTo(360));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
