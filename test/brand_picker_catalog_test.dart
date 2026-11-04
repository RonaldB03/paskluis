import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/services/brand_picker_catalog.dart';
import 'package:paskluis_v1/data/templates/card_templates.dart';

void main() {
  final dutch = cardBrandTemplateFromJson({
    'slug': 'albert-heijn',
    'name': 'Albert Heijn',
    'is_featured': true,
  });
  final belgian = cardBrandTemplateFromJson({
    'slug': 'colruyt-be',
    'name': 'Colruyt',
    'country_code': 'BE',
    'aliases': ['Xtra', 'Okay'],
  });
  final brands = [dutch, belgian];

  test(
    'Belgian stores precede even featured Dutch stores on a Belgian phone',
    () {
      final catalog = buildBrandPickerCatalog(
        brands,
        query: '',
        countryCode: 'BE',
      );
      expect(catalog.popular, isEmpty);
      expect(catalog.stores, [belgian, dutch]);
    },
  );

  test('Dutch and unknown regions retain the existing featured section', () {
    for (final country in ['NL', 'FR', null]) {
      final catalog = buildBrandPickerCatalog(
        brands,
        query: '',
        countryCode: country,
      );
      expect(catalog.popular, [dutch]);
      expect(catalog.stores, [belgian]);
    }
  });

  test('search finds stores and aliases across both countries', () {
    final matches = buildBrandPickerCatalog(
      brands,
      query: ' al ',
      countryCode: 'BE',
    );
    expect(matches.popular, isEmpty);
    expect(matches.stores, [dutch]);

    final alias = buildBrandPickerCatalog(
      brands,
      query: 'Xtra',
      countryCode: 'NL',
    );
    expect(alias.stores, [belgian]);
  });

  test('one result per store name prefers the phone region', () {
    final dutchAction = cardBrandTemplateFromJson({
      'slug': 'action-nl',
      'name': 'Action',
      'country_code': 'NL',
    });
    final belgianAction = cardBrandTemplateFromJson({
      'slug': 'action-be',
      'name': ' action ',
      'country_code': 'BE',
    });
    final duplicates = [dutchAction, belgianAction, dutchAction];

    for (final query in ['', 'Action']) {
      for (final (region, expected) in [
        ('BE', belgianAction),
        ('NL', dutchAction),
      ]) {
        final catalog = buildBrandPickerCatalog(
          duplicates,
          query: query,
          countryCode: region,
        );
        expect([...catalog.popular, ...catalog.stores], [expected]);
      }
    }
  });
}
