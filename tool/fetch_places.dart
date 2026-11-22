// Downloads named places of Aral from OpenStreetMap (Overpass API) and writes
// the compact search index bundled with the app.
//
// Run from the project root:  dart run tool/fetch_places.dart
//
// Data © OpenStreetMap contributors, ODbL 1.0.

import 'dart:convert';
import 'dart:io';

/// south, west, north, east — the town of Aral with its outskirts.
const bbox = '46.74,61.57,46.85,61.76';
const overpassUrl = 'https://overpass-api.de/api/interpreter';
const outPath = 'assets/data/aral_places.json';

const query =
    '''
[out:json][timeout:90];
(
  nwr["name"]["amenity"]($bbox);
  nwr["name"]["shop"]($bbox);
  nwr["name"]["tourism"]($bbox);
  nwr["name"]["leisure"]($bbox);
  nwr["name"]["office"]($bbox);
  nwr["name"]["healthcare"]($bbox);
  nwr["name"]["historic"]($bbox);
  nwr["name"]["craft"]($bbox);
  nwr["name"]["railway"="station"]($bbox);
  nwr["name"]["public_transport"="station"]($bbox);
  way["name"]["highway"]($bbox);
  nwr["name"]["place"]($bbox);
);
out center tags;
''';

/// OSM tags → app category id. First match wins.
String? categoryOf(Map<String, dynamic> t) {
  final amenity = t['amenity'], shop = t['shop'], tourism = t['tourism'];
  if (t['highway'] != null) return 'street';
  if (t['place'] != null) return 'district';
  switch (amenity) {
    case 'pharmacy':
      return 'pharmacy';
    case 'hospital' || 'clinic' || 'doctors' || 'dentist':
      return 'health';
    case 'school' || 'kindergarten' || 'college' || 'university':
      return 'education';
    case 'cafe' || 'restaurant' || 'fast_food' || 'bar' || 'canteen':
      return 'food';
    case 'bank' || 'atm' || 'bureau_de_change':
      return 'finance';
    case 'place_of_worship':
      return 'religion';
    case 'fuel':
      return 'fuel';
    case 'police' || 'fire_station':
      return 'emergency';
    case 'post_office':
      return 'post';
    case 'bus_station':
      return 'transport';
    case 'marketplace':
      return 'market';
    case 'townhall' || 'courthouse':
      return 'government';
  }
  if (t['healthcare'] != null) return 'health';
  if (t['railway'] == 'station' || t['public_transport'] == 'station') {
    return 'transport';
  }
  if (shop == 'supermarket' || shop == 'convenience' || shop == 'grocery') {
    return 'grocery';
  }
  if (shop != null) return 'shop';
  if (tourism == 'hotel' || tourism == 'guest_house' || tourism == 'hostel') {
    return 'lodging';
  }
  if (tourism != null || t['historic'] != null) return 'sight';
  if (t['leisure'] == 'park' || t['leisure'] == 'garden') return 'park';
  if (t['office'] == 'government') return 'government';
  if (t['leisure'] != null) return 'leisure';
  if (amenity != null || t['office'] != null || t['craft'] != null) {
    return 'other';
  }
  return null;
}

Future<void> main() async {
  stdout.writeln('Querying Overpass for bbox $bbox …');
  final client = HttpClient()..userAgent = 'AralMap-data-script/1.0';
  final request = await client.postUrl(Uri.parse(overpassUrl));
  request.headers.contentType = ContentType(
    'application',
    'x-www-form-urlencoded',
    charset: 'utf-8',
  );
  request.write('data=${Uri.encodeQueryComponent(query)}');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  client.close();
  if (response.statusCode != 200) {
    stderr.writeln('Overpass HTTP ${response.statusCode}:\n$body');
    exit(1);
  }

  final elements = (jsonDecode(body)['elements'] as List)
      .cast<Map<String, dynamic>>();

  final places = <Map<String, Object>>[];
  // Streets are split into many OSM ways, and some objects are mapped twice
  // (node + building); keep one entry per name and category.
  final seen = <String>{};
  var skipped = 0;

  for (final e in elements) {
    final tags = (e['tags'] as Map).cast<String, dynamic>();
    final category = categoryOf(tags);
    final lat = (e['lat'] ?? e['center']?['lat']) as num?;
    final lon = (e['lon'] ?? e['center']?['lon']) as num?;
    final name = (tags['name'] as String?)?.trim();
    if (category == null || lat == null || lon == null || name == null) {
      skipped++;
      continue;
    }
    if (!seen.add('$category|${name.toLowerCase()}')) continue;

    final nameRu = (tags['name:ru'] as String?)?.trim();
    final nameKk = (tags['name:kk'] as String?)?.trim();
    places.add({
      'n': name,
      if (nameRu != null && nameRu != name) 'ru': nameRu,
      if (nameKk != null && nameKk != name) 'kk': nameKk,
      'c': category,
      // ~1 m precision is plenty and keeps the file small.
      'la': double.parse(lat.toStringAsFixed(5)),
      'lo': double.parse(lon.toStringAsFixed(5)),
    });
  }

  places.sort((a, b) => (a['n'] as String).compareTo(b['n'] as String));

  final out = File(outPath)..createSync(recursive: true);
  out.writeAsStringSync(
    jsonEncode({
      'attribution': '© OpenStreetMap contributors, ODbL 1.0',
      'generated': DateTime.now().toUtc().toIso8601String(),
      'bbox': bbox,
      'places': places,
    }),
  );

  final byCategory = <String, int>{};
  for (final p in places) {
    byCategory.update(p['c'] as String, (v) => v + 1, ifAbsent: () => 1);
  }
  final sorted = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stdout
    ..writeln('OSM elements: ${elements.length}, skipped: $skipped')
    ..writeln(
      'Places written: ${places.length} → $outPath '
      '(${(out.lengthSync() / 1024).toStringAsFixed(1)} KB)',
    )
    ..writeln(sorted.map((e) => '${e.key}: ${e.value}').join(', '));
}
