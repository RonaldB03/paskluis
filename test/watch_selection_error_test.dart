import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/features/settings/watch_selection_error.dart';

void main() {
  test(
    'barcode validation failures are not presented as a card count limit',
    () {
      for (final language in ['nl', 'en']) {
        for (final reason in [
          'too_wide',
          'unsupported',
          'invalid_code',
          'code_too_long',
        ]) {
          final text = watchSelectionError(
            FormatException(reason, 'Testpas'),
            language,
          );
          expect(text, contains('Testpas'));
          expect(text, isNot(contains('12')));
        }
        expect(
          watchSelectionError(const FormatException('too_many'), language),
          contains('12'),
        );
      }
    },
  );
}
