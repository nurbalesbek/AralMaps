// Downloads the sight photos from Wikimedia Commons and writes their credits
// (author, license, source) to assets/photos/credits.json, which the app
// shows under every photo.
//
// Run from the project root:  dart run tool/fetch_photos.dart
//
// Only freely licensed files are used, chosen by looking at each one:
// many "Aral Sea ship cemetery" photos on Commons are from Moynaq
// (Uzbekistan), not from Aral, and are deliberately not used.

import 'dart:convert';
import 'dart:io';

/// app key → (Commons file, width to download)
/// (The harbour photo doubles as the Explore header.)
const photos = {
  'harbour-fishermen-museum': ('File:Aral harbour.jpg', 1080),
  'zhalanash': (
    'File:The Aral sea is drying up. Bay of Zhalanash, Ship Cemetery, Aralsk, Kazakhstan.jpg',
    1080,
  ),
  'north-aral-sea': (
    'File:Aerial view of North Aral Sea in 2013 (1).jpg',
    1080,
  ),
  'kokaral-dam': (
    'File:Dike Kokaral 2021-07-20 Sentinel-2 L2A True color.jpg',
    1080,
  ),
  // History chapters.
  'history-fish-factory': ('File:Fish factory, Aralsk, Kazakhstan.jpg', 1080),
  // A PNG: smaller width keeps it under ~0.5 MB.
  'history-sea-1964-2026': ('File:Aral Sea 1964 vs. August 25, 2026.png', 720),
};
// Checked and NOT used: "20231216 Aral Railway Station 01/02.jpg" show
// Alar station in China (阿拉尔站), not Aral; "A school overtaken by the
// dune, Aral" shows a shrub, not a school.

const outDir = 'assets/photos';

String _plain(String? html) => (html ?? '')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Future<void> main() async {
  final client = HttpClient()..userAgent = 'AralMap-data-script/1.0';
  Directory(outDir).createSync(recursive: true);
  final credits = <String, Object>{};
  var totalBytes = 0;

  for (final MapEntry(key: key, value: (title, width)) in photos.entries) {
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'titles': title,
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata',
      'iiurlwidth': '$width',
    });
    final res = await (await client.getUrl(uri)).close();
    final page =
        (jsonDecode(await res.transform(utf8.decoder).join())['query']['pages']
                    as Map)
                .values
                .first
            as Map;
    final info = (page['imageinfo'] as List).first as Map;
    final meta = (info['extmetadata'] as Map).cast<String, dynamic>();
    String m(String k) => _plain(meta[k]?['value'] as String?);

    final license = m('LicenseShortName');
    if (license.isEmpty) {
      stderr.writeln('$title: no license — skipped');
      continue;
    }

    final thumb = info['thumburl'] as String;
    final img = await (await client.getUrl(Uri.parse(thumb))).close();
    final ext = thumb.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final file = File('$outDir/$key.$ext');
    await img.pipe(file.openWrite());
    totalBytes += file.lengthSync();

    credits[key] = {
      'asset': '$key.$ext',
      'file': title,
      'author': m('Artist').isNotEmpty ? m('Artist') : m('Credit'),
      'credit': m('Attribution'),
      'license': license,
      'licenseUrl': m('LicenseUrl'),
      'source': info['descriptionurl'],
      'date': m('DateTimeOriginal'),
    };
    stdout.writeln(
      '$key.jpg  ${(file.lengthSync() / 1024).round()} KB  '
      '$license  ${credits[key]}',
    );
  }
  client.close();

  File('$outDir/credits.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(credits));
  stdout.writeln('Total ${(totalBytes / 1024).round()} KB');
}
