import 'place.dart';

/// Kazakh-specific letters folded to their closest Russian letter, so
/// "кошеси" finds "көшесі" and "актобе" finds "Ақтөбе".
const _fold = {
  'ә': 'а',
  'ғ': 'г',
  'қ': 'к',
  'ң': 'н',
  'ө': 'о',
  'ұ': 'у',
  'ү': 'у',
  'һ': 'х',
  'і': 'и',
  'ё': 'е',
};

final _separators = RegExp(r'''[\s\-–—_.,;:!?"'«»()№#/\\]+''');

/// Lower-case, fold Kazakh letters, and collapse punctuation to spaces.
String normalizeForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_fold[ch] ?? ch);
  }
  return buffer.toString().replaceAll(_separators, ' ').trim();
}

/// Precomputed, normalized text of a place, built once per dataset.
class _Entry {
  _Entry(this.place)
    : names = [
        normalizeForSearch(place.name),
        for (final n in place.altNames) normalizeForSearch(n),
      ],
      keywords = [
        normalizeForSearch(place.category.label),
        for (final k in place.category.keywords) normalizeForSearch(k),
      ];

  final Place place;
  final List<String> names;
  final List<String> keywords;
}

/// In-memory search over the bundled places. All work is local and fast
/// enough to run on every keystroke (a few hundred entries).
class PlaceSearch {
  PlaceSearch(List<Place> places)
    : _entries = [for (final p in places) _Entry(p)];

  final List<_Entry> _entries;

  static const defaultLimit = 40;

  List<Place> search(String query, {int limit = defaultLimit}) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return const [];
    final terms = q.split(' ');

    final scored = <(int, _Entry)>[];
    for (final entry in _entries) {
      final score = _score(entry, q, terms);
      if (score > 0) scored.add((score, entry));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0
          ? byScore
          : a.$2.place.name.compareTo(b.$2.place.name);
    });
    return [for (final (_, e) in scored.take(limit)) e.place];
  }

  /// 0 = no match. Higher is better: whole name > name start > word start >
  /// substring > category keyword. Every term must match somewhere.
  static int _score(_Entry e, String q, List<String> terms) {
    var best = 0;
    for (final name in e.names) {
      if (name == q) return 100;
      if (name.startsWith(q)) {
        best = best < 80 ? 80 : best;
      } else if (_allTermsMatchWordStarts(name, terms)) {
        best = best < 60 ? 60 : best;
      } else if (terms.every(name.contains)) {
        best = best < 40 ? 40 : best;
      }
    }
    if (best > 0) return best;

    // "аптека", "школа" … find places of that kind even without the word
    // in their name. Needs 2+ letters, or "а" would match half the town.
    if (q.length < 2) return 0;
    for (final keyword in e.keywords) {
      final matchesKeyword = keyword.startsWith(q) || q.startsWith(keyword);
      if (matchesKeyword) return 20;
    }
    return 0;
  }

  static bool _allTermsMatchWordStarts(String name, List<String> terms) {
    final words = name.split(' ');
    return terms.every((t) => words.any((w) => w.startsWith(t)));
  }
}
