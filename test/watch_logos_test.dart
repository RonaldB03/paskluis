import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/services/watch_logos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('exports only selected logos as bounded PNG thumbnails', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final result = await WatchLogos.build(
        [
          {'id': 'selected', 'logoAsset': 'assets/logos/albert_heijn.png'},
          {'id': 'private', 'logoAsset': 'assets/logos/hema.png'},
          {'id': 'missing', 'logoAsset': 'assets/logos/does-not-exist.png'},
        ],
        {'selected', 'missing'},
      );
      expect(result.keys, ['selected']);
      final bytes = base64Decode(result['selected']!);
      expect(bytes.length, lessThanOrEqualTo(4500));
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, lessThanOrEqualTo(64));
      expect(frame.image.height, lessThanOrEqualTo(64));
      frame.image.dispose();
      codec.dispose();
    });
  });
  test('empty selection sends no logos', () async {
    expect(
      await WatchLogos.build([
        {'id': 'one', 'logoAsset': 'assets/logos/hema.png'},
      ], {}),
      isEmpty,
    );
  });
}
