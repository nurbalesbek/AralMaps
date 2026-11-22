import 'package:aralmap/features/search/domain/place.dart';
import 'package:aralmap/features/search/domain/place_search.dart';
import 'package:flutter_test/flutter_test.dart';

Place _p(String name, PlaceCategory c, [List<String> alt = const []]) => Place(
  name: name,
  altNames: alt,
  category: c,
  latitude: 46.8,
  longitude: 61.67,
);

final _places = [
  _p('Ізтай Айбосынов көшесі', PlaceCategory.street),
  _p('Абая', PlaceCategory.street),
  _p('Абдикер Каюпова', PlaceCategory.street),
  _p('Europharma', PlaceCategory.pharmacy),
  _p('Жанар және Компания', PlaceCategory.pharmacy, ['Жанар и Компания']),
  _p('13 орта мектеп', PlaceCategory.education, ['Средняя школа 13']),
  _p('Лицей 2', PlaceCategory.education),
  _p('Роддом', PlaceCategory.health),
  _p('Авто Бекетi', PlaceCategory.transport, ['Автовокзал']),
];

List<String> _names(String q) =>
    PlaceSearch(_places).search(q).map((p) => p.name).toList();

void main() {
  group('normalizeForSearch', () {
    test('folds Kazakh letters and ё, lowercases', () {
      expect(normalizeForSearch('Көшесі Ақтөбе Ёлка'), 'кошеси актобе елка');
    });

    test('turns punctuation into single spaces', () {
      expect(normalizeForSearch(' Лицей  №16 «КТМ» '), 'лицей 16 ктм');
    });
  });

  group('PlaceSearch', () {
    test('empty or blank query returns nothing', () {
      expect(_names(''), isEmpty);
      expect(_names('   '), isEmpty);
    });

    test('Russian spelling finds Kazakh names', () {
      expect(_names('айбосынов кошеси'), ['Ізтай Айбосынов көшесі']);
    });

    test('name start ranks above a match inside the name', () {
      expect(_names('аб'), ['Абая', 'Абдикер Каюпова']);
    });

    test('alternative-language name is searched', () {
      expect(_names('жанар и'), ['Жанар және Компания']);
      expect(_names('автовокзал'), ['Авто Бекетi']);
    });

    test('category word finds places without it in the name', () {
      expect(
        _names('аптека'),
        containsAll(['Europharma', 'Жанар және Компания']),
      );
      expect(_names('больница'), ['Роддом']);
    });

    test('name matches rank above category-only matches', () {
      final results = _names('школа');
      expect(results.first, '13 орта мектеп');
      expect(results, contains('Лицей 2'));
    });

    test('one letter does not match whole categories', () {
      expect(_names('а'), isNot(contains('Europharma')));
    });

    test('nonsense finds nothing', () {
      expect(_names('zzzz'), isEmpty);
    });
  });
}
