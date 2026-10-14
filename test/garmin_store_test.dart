import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/services/garmin_store.dart';

void main() {
  test('unconfigured or invalid listings never produce a store link', () {
    for (final id in [
      '',
      'pending',
      'https://example.com',
      '../apps',
      '5fdfca8919394cb8b3bbd96184aa208c',
    ]) {
      expect(GarminStore.listingUri(id), isNull);
    }
    expect(
      GarminStore.listingUri('00000000-0000-0000-0000-000000000001').toString(),
      'https://apps.garmin.com/apps/00000000-0000-0000-0000-000000000001',
    );
  });
}
