import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/templates/card_templates.dart';
import 'package:paskluis_v1/features/cards/choose_card_template_screen.dart';
import 'package:paskluis_v1/features/gift_cards/add_gift_card_screen.dart';
import 'package:paskluis_v1/l10n/generated/app_localizations.dart';

const _captureKey = ValueKey('belgian-preview');
const _brands = [
  CardBrandTemplate(
    id: 'albert-heijn',
    name: 'Albert Heijn',
    color: Color(0xff00a6d6),
    logoAsset: 'assets/logos/albert_heijn.png',
    isFeatured: true,
    supportedTypes: ['Pasje', 'Cadeaukaart'],
  ),
  CardBrandTemplate(
    id: 'colruyt-be',
    name: 'Colruyt Xtra',
    countryCode: 'BE',
    color: Color(0xffd21a20),
    logoAsset: '',
    searchTerms: ['okay', 'bio-planet'],
  ),
  CardBrandTemplate(
    id: 'delhaize-be',
    name: 'Delhaize SuperPlus',
    countryCode: 'BE',
    color: Color(0xffe41e2b),
    logoAsset: '',
  ),
  CardBrandTemplate(
    id: 'carrefour-be',
    name: 'Carrefour Bonus Card',
    countryCode: 'BE',
    color: Color(0xff145ba9),
    logoAsset: '',
  ),
  CardBrandTemplate(
    id: 'action-be',
    name: 'Action',
    countryCode: 'BE',
    color: Color(0xff0057a8),
    logoAsset: '',
    supportedTypes: ['Cadeaukaart'],
  ),
  CardBrandTemplate(
    id: 'vanden-borre-be',
    name: 'Vanden Borre',
    countryCode: 'BE',
    color: Color(0xffeb1c24),
    logoAsset: '',
    supportedTypes: ['Cadeaukaart'],
  ),
];

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  Locale deviceLocale = const Locale('en', 'BE'),
  bool animated = false,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.platformDispatcher.localeTestValue = deviceLocale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  final output = Platform.environment['PASKLUIS_PREVIEW_DIR'];
  if (output != null) {
    await tester.runAsync(() async {
      final fonts = FontLoader('Preview');
      for (final name in ['segoeui.ttf', 'segoeuib.ttf']) {
        fonts.addFont(
          File(
            'C:/Windows/Fonts/$name',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await fonts.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        File(
          '../.tooling/flutter/bin/cache/dart-sdk/bin/resources/devtools/'
          'assets/fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
      await icons.load();
    });
  }

  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          fontFamily: output == null ? null : 'Preview',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffd51b46)),
        ),
        home: screen,
      ),
    ),
  );
  if (animated) {
    await tester.pump(const Duration(milliseconds: 350));
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final output = Platform.environment['PASKLUIS_PREVIEW_DIR'];
  if (output == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('$output/$name.png').writeAsBytes(png.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  testWidgets(
    'loyalty picker prioritizes Belgium and searches both countries',
    (tester) async {
      await _open(tester, const ChooseCardTemplateScreen(type: 'Pasje'));
      final dynamic state = tester.state(find.byType(ChooseCardTemplateScreen));
      state.brands = _brands;
      tester.element(find.byType(ChooseCardTemplateScreen)).markNeedsBuild();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Carrefour Bonus Card'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Carrefour Bonus Card')).dy,
        lessThan(tester.getTopLeft(find.text('Albert Heijn')).dy),
      );
      await _capture(tester, '01-belgische-klantenkaarten');

      await tester.enterText(find.byType(TextField), 'Okay');
      await tester.pumpAndSettle();
      expect(find.text('Colruyt Xtra'), findsOneWidget);
      expect(find.text('Albert Heijn'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Albert');
      await tester.pumpAndSettle();
      expect(find.text('Albert Heijn'), findsOneWidget);
      expect(find.text('Colruyt Xtra'), findsNothing);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _capture(tester, '02-zoeken-over-de-grens');
    },
  );

  testWidgets(
    'gift picker prioritizes Belgium and keeps Dutch search results',
    (tester) async {
      const regionChannel = MethodChannel('nl.paskluis.app/device-region');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(regionChannel, (call) async {
        expect(call.method, 'countryCode');
        return 'BE';
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(regionChannel, null),
      );
      await _open(
        tester,
        Scaffold(
          backgroundColor: const Color(0xfff4f4f6),
          body: GiftBrandPickerSheet(
            height: 844,
            brands: _brands
                .where((brand) => brand.supportedTypes.contains('Cadeaukaart'))
                .toList(),
          ),
        ),
        deviceLocale: const Locale('nl', 'NL'),
      );
      expect(
        tester.getTopLeft(find.text('Action')).dy,
        lessThan(tester.getTopLeft(find.text('Albert Heijn')).dy),
      );
      await _capture(tester, '03-belgische-cadeaukaarten');

      await tester.enterText(find.byType(TextField), 'Albert');
      await tester.pumpAndSettle();
      expect(find.text('Albert Heijn'), findsOneWidget);
      expect(find.text('Action'), findsNothing);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('example gift card opens with a scannable code', (tester) async {
    await _open(
      tester,
      Scaffold(
        appBar: AppBar(title: const Text('Cadeaukaart')),
        backgroundColor: const Color(0xfff4f4f6),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: GiftCardLivePreview(
            name: 'Action',
            code: '000000000001',
            formattedCode: '000000000001',
            barcode: Barcode.code128(),
            balance: '25.00',
            cardColor: const Color(0xff0057a8),
            logoAsset: '',
            customImage: '',
            isQr: false,
            logoLayout: const {},
          ),
        ),
      ),
      animated: true,
    );
    expect(find.text('Action'), findsOneWidget);
    expect(find.byType(BarcodeWidget), findsOneWidget);
    await _capture(tester, '04-voorbeeld-cadeaukaart');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
