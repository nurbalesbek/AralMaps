import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Author and license of a bundled photo (assets/photos/credits.json,
/// written by tool/fetch_photos.dart). Shown under every photo.
class PhotoCredit {
  const PhotoCredit({
    required this.author,
    required this.license,
    required this.source,
    this.credit = '',
    this.year,
  });

  factory PhotoCredit.fromJson(Map<String, dynamic> j) => PhotoCredit(
    author: j['author'] as String? ?? '',
    license: j['license'] as String? ?? '',
    source: j['source'] as String? ?? '',
    credit: j['credit'] as String? ?? '',
    year: RegExp(r'\b(19|20)\d\d\b')
        .firstMatch(j['date'] as String? ?? '')
        ?.group(0),
  );

  final String author;
  final String license;

  /// The file page on Wikimedia Commons.
  final String source;

  /// Extra attribution required by some licenses (e.g. Copernicus data).
  final String credit;
  final String? year;

  /// "Фото: Yorian · CC BY-SA 3.0 · 2009", or for satellite data with a
  /// required credit: "Снимок: European Space Agency · Contains modified…".
  String get line => credit.isNotEmpty
      ? 'Снимок: $author · $credit'
      : ['Фото: $author', license, ?year].join(' · ');
}

/// Photo asset path and credit by key (a sight id).
typedef SightPhoto = ({String asset, PhotoCredit credit});

final sightPhotosProvider = FutureProvider<Map<String, SightPhoto>>((
  ref,
) async {
  final raw = await rootBundle.loadString('assets/photos/credits.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key: (
        asset:
            'assets/photos/${(value as Map)['asset'] as String? ?? '$key.jpg'}',
        credit: PhotoCredit.fromJson(value as Map<String, dynamic>),
      ),
  };
});
