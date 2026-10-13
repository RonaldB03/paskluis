import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/shared/utils/printed_card_number.dart';

void main() {
  test('keeps leading zeros and grouped card numbers', () {
    expect(
      printedCardNumber(['Kaart: 0012 3456 7890 1234']),
      '0012345678901234',
    );
    expect(printedCardNumber(['0012-3456-7890-1234']), '0012345678901234');
  });

  test('same number printed twice is not concatenated', () {
    expect(printedCardNumber(['123456789012 123456789012']), '123456789012');
    expect(printedCardNumber(['123456789012', '123456789012']), '123456789012');
  });

  test('does not guess between different numbers', () {
    expect(printedCardNumber(['12345678 987654321012']), '');
    expect(printedCardNumber(['12345678', '987654321012']), '');
  });

  test('does not append a PIN to an ungrouped card number', () {
    expect(printedCardNumber(['1234567890123456 1234']), '1234567890123456');
  });

  test('never extracts a truncated number from an overlong digit run', () {
    expect(printedCardNumber(['123456789012345678901234567890']), '');
    expect(printedCardNumber(['1234 5678 9012 3456 7890 1234 5678']), '');
  });

  test('separate lines and columns are not joined', () {
    expect(printedCardNumber(['1234', '5678']), '');
    expect(printedCardNumber(['1234  5678']), '');
    expect(printedCardNumber(['1234\t5678']), '');
  });
}
