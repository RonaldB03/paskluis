import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/core/theme/app_theme.dart';
import 'package:paskluis_v1/data/services/watch_service.dart';
import 'package:paskluis_v1/features/settings/watch_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'paired screen hides platform picker and syncs each selection automatically',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('paskluis-watch-screen-'),
      );
      Hive.init(directory!.path);
      final box = (await tester.runAsync(() => Hive.openBox('cards')))!;
      for (final name in ['Albert Heijn', 'Gall & Gall', 'Sligro', 'Makro']) {
        await tester.runAsync(
          () => box.put(name, {
            'id': name,
            'name': name,
            'type': 'Pasje',
            'code': '12345670',
            'barcodeSymbology': 'ean8',
          }),
        );
      }
      SharedPreferences.setMockInitialValues({
        'watch.owner': 'screen-preview',
        'watch.target': 'wear',
        'watch.name': 'Galaxy Watch8',
        'watch.wear.enabled': true,
        'watch.wear.selected': ['Albert Heijn'],
      });
      final snapshots = <Map>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WatchService.channel, (call) async {
            if (call.method == 'status') {
              return {
                'wear': {'confirmed': true},
              };
            }
            if (call.method == 'replace') {
              snapshots.add(
                jsonDecode((call.arguments as Map)['snapshot'] as String)
                    as Map,
              );
            }
            return null;
          });
      final service = WatchService.instance;
      await tester.runAsync(service.init);
      if (const bool.fromEnvironment('WATCH_PREVIEW')) {
        await tester.runAsync(() async {
          for (final font in {
            'Roboto': 'roboto-regular.ttf',
            'MaterialIcons': 'materialicons-regular.otf',
          }.entries) {
            final loader = FontLoader(font.key);
            loader.addFont(
              File(
                '../.tooling/flutter/bin/cache/artifacts/material_fonts/${font.value}',
              ).readAsBytes().then(ByteData.sublistView),
            );
            await loader.load();
          }
        });
      }
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const WatchSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Galaxy Watch8'), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.text('Synchroniseren'), findsNothing);
      expect(find.text('Wijzigingen opslaan'), findsNothing);
      await tester.tap(find.text('Gall & Gall'));
      await tester.pumpAndSettle();
      expect((snapshots.last['cards'] as List).length, 2);
      await tester.tap(find.text('Albert Heijn'));
      await tester.pumpAndSettle();
      expect((snapshots.last['cards'] as List).single['name'], 'Gall & Gall');
      await tester.tap(find.text('Albert Heijn'));
      await tester.pumpAndSettle();
      expect((snapshots.last['cards'] as List).length, 2);
      if (const bool.fromEnvironment('WATCH_PREVIEW')) {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        await tester.runAsync(() async {
          await Directory('build/watch-phone-preview').create(recursive: true);
          await File(
            'build/watch-phone-preview/paired.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      await tester.runAsync(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WatchService.channel, null);
    },
    skip: !WatchService.betaEnabled,
  );
}
