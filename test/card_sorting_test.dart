import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/shared/utils/card_sorting.dart';

Map<String, dynamic> card(String id, {bool favorite = false, String? created, String? used}) => {
  'id': id,
  'type': 'Pasje',
  'name': id,
  'isFavorite': favorite,
  'createdAt': created,
  'lastUsedAt': used,
};

void main() {
  List<String> ids(List<Map<String, dynamic>> cards) =>
      cards.map((card) => card['id'] as String).toList();

  test('nearest cards within radius precede favorites and ordinary sorting', () {
    final cards = [card('Z', favorite: true), card('A'), card('B'), card('C')];
    final sorted = sortLoyaltyCards(cards,
      favoritesFirst: true, sortOrder: 'alphabetical', nearbyFirst: true,
      distances: {'A': 251, 'B': 250, 'C': 20});
    expect(ids(sorted), ['C', 'B', 'Z', 'A']);
    expect(ids(cards), ['Z', 'A', 'B', 'C']);
  });

  test('disabled nearby sorting respects the favorites preference', () {
    final cards = [card('Z', favorite: true), card('B'), card('A')];
    expect(ids(sortLoyaltyCards(cards, favoritesFirst: true,
      sortOrder: 'alphabetical', distances: {'B': 0})), ['Z', 'A', 'B']);
    expect(ids(sortLoyaltyCards(cards, favoritesFirst: false,
      sortOrder: 'alphabetical', distances: {'B': 0})), ['A', 'B', 'Z']);
  });

  test('missing and invalid distances fall back to normal ordering', () {
    final cards = [card('D'), card('B'), card('A'), card('C')];
    expect(ids(sortLoyaltyCards(cards, favoritesFirst: false,
      sortOrder: 'alphabetical', nearbyFirst: true,
      distances: {'A': double.nan, 'B': -1, 'C': double.infinity})),
      ['A', 'B', 'C', 'D']);
  });

  test('recent and added sorting use the chosen date, with stable ties', () {
    final cards = [
      card('old', created: '2026-01-01', used: '2026-09-22'),
      card('new', created: '2026-09-21'), card('tie1'), card('tie2'),
    ];
    expect(ids(sortLoyaltyCards(cards, favoritesFirst: false, sortOrder: 'recent')),
      ['old', 'new', 'tie1', 'tie2']);
    expect(ids(sortLoyaltyCards(cards, favoritesFirst: false, sortOrder: 'added')),
      ['new', 'old', 'tie1', 'tie2']);
  });

  test('equal distances fall back to favorites then normal ordering', () {
    final cards = [card('B'), card('Z', favorite: true), card('A')];
    expect(ids(sortLoyaltyCards(cards, favoritesFirst: true,
      sortOrder: 'alphabetical', nearbyFirst: true,
      distances: {'A': 0, 'B': 0, 'Z': 0})), ['Z', 'A', 'B']);
  });
}
