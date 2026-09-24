import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/shared/utils/brand_display_name.dart';

void main() {
  const names = {
    'hema': 'HEMA',
    'Albert Heijn': 'Albert Heijn',
    'gall-gall': 'Gall & Gall',
    'h-and-m': 'H&M',
  };

  test('shows catalogue spelling including acronyms and punctuation', () {
    expect(brandDisplayName('hema', names), 'HEMA');
    expect(brandDisplayName('gall-gall', names), 'Gall & Gall');
    expect(brandDisplayName('h-and-m', names), 'H&M');
  });

  test('recognizes legacy capitalization and separator variants', () {
    expect(brandDisplayName('Hema', names), 'HEMA');
    expect(brandDisplayName('albert_heijn', names), 'Albert Heijn');
  });

  test('formats unknown identifiers and keeps empty identifiers empty', () {
    expect(brandDisplayName('nieuwe-winkel', names), 'Nieuwe Winkel');
    expect(brandDisplayName('', names), '');
  });
}
