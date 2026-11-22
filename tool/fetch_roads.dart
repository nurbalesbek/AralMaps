// Downloads the road network of Aral from OpenStreetMap (Overpass API) and
// writes the compact routing graph bundled with the app.
//
// Run from the project root:  dart run tool/fetch_roads.dart
//
// Data © OpenStreetMap contributors, ODbL 1.0.

import 'dart:convert';
import 'dart:io';

/// south, west, north, east — same area as the place index.
const bbox = '46.74,61.57,46.85,61.76';
const overpassUrl = 'https://overpass-api.de/api/interpreter';
const outPath = 'assets/data/aral_roads.json';

const query =
    '''
[out:json][timeout:120];
way["highway"]($bbox);
(._;>;);
out body;
''';

/// Road classes, in the order the app's speed table expects (see
/// lib/features/routing/domain/road_graph.dart). Index is stored per edge.
const roadClasses = [
  'motorway', // 0
  'trunk', // 1
  'primary', // 2
  'secondary', // 3
  'tertiary', // 4
  'unclassified', // 5
  'residential', // 6
  'living_street', // 7
  'service', // 8
  'track', // 9
  'path', // 10: footway, path, pedestrian, steps, cycleway, bridleway
];

const _footOnly = {
  'footway',
  'path',
  'pedestrian',
  'steps',
  'cycleway',
  'bridleway',
  'corridor',
};
const _skip = {
  'construction',
  'proposed',
  'abandoned',
  'disused',
  'razed',
  'platform',
  'bus_stop',
  'elevator',
  'raceway',
};

/// Edge flags.
const foot = 1, carForward = 2, carBackward = 4;

int? classOf(String highway) {
  if (_footOnly.contains(highway)) return 10;
  final base = highway.endsWith('_link')
      ? highway.substring(0, highway.length - 5)
      : highway;
  final i = roadClasses.indexOf(base);
  if (i >= 0) return i;
  if (highway == 'road') return 5; // unknown type: treat as unclassified
  return null;
}

/// Which modes may use the way, and in which direction for cars.
int? flagsOf(Map<String, dynamic> t, int roadClass) {
  final access = t['access'];
  if (access == 'no' || access == 'private') return null;

  var flags = 0;
  final footTag = t['foot'];
  final footAllowed =
      footTag != 'no' &&
      footTag != 'private' &&
      roadClass != 0 && // no walking on motorways
      t['highway'] != 'trunk_link';
  if (footAllowed) flags |= foot;

  final motor = t['motor_vehicle'] ?? t['vehicle'];
  final carAllowed =
      roadClass != 10 &&
      motor != 'no' &&
      motor != 'private' &&
      t['motorcar'] != 'no';
  if (carAllowed) {
    final oneway = t['oneway'];
    final roundabout = t['junction'] == 'roundabout';
    if (oneway == '-1') {
      flags |= carBackward;
    } else if (oneway == 'yes' ||
        oneway == 'true' ||
        oneway == '1' ||
        roundabout ||
        roadClass == 0) {
      flags |= carForward;
    } else {
      flags |= carForward | carBackward;
    }
  }
  return flags == 0 ? null : flags;
}

Future<void> main() async {
  stdout.writeln('Querying Overpass for roads in $bbox …');
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

  final coords = <int, (int, int)>{}; // OSM node id → (lat·1e5, lon·1e5)
  for (final e in elements.where((e) => e['type'] == 'node')) {
    coords[e['id'] as int] = (
      ((e['lat'] as num) * 1e5).round(),
      ((e['lon'] as num) * 1e5).round(),
    );
  }

  // Every OSM node on a usable way becomes a vertex: the graph is small
  // (one town), and it keeps snapping and drawing exact.
  final vertexOf = <int, int>{};
  final vertices = <int>[]; // flat lat, lon
  final edges = <int>[]; // flat a, b, flags, class
  var ways = 0, skippedWays = 0;

  int vertex(int osmId) => vertexOf.putIfAbsent(osmId, () {
    final (lat, lon) = coords[osmId]!;
    vertices
      ..add(lat)
      ..add(lon);
    return vertices.length ~/ 2 - 1;
  });

  for (final e in elements.where((e) => e['type'] == 'way')) {
    final tags = (e['tags'] as Map).cast<String, dynamic>();
    final highway = tags['highway'] as String;
    final roadClass = _skip.contains(highway) ? null : classOf(highway);
    final flags = roadClass == null ? null : flagsOf(tags, roadClass);
    final nodes = (e['nodes'] as List).cast<int>();
    if (roadClass == null ||
        flags == null ||
        nodes.any((n) => !coords.containsKey(n))) {
      skippedWays++;
      continue;
    }
    ways++;
    for (var i = 0; i + 1 < nodes.length; i++) {
      if (nodes[i] == nodes[i + 1]) continue;
      edges
        ..add(vertex(nodes[i]))
        ..add(vertex(nodes[i + 1]))
        ..add(flags)
        ..add(roadClass);
    }
  }

  // Store vertices delta-encoded: small numbers make a much smaller file.
  final delta = <int>[];
  var pLat = 0, pLon = 0;
  for (var i = 0; i < vertices.length; i += 2) {
    delta
      ..add(vertices[i] - pLat)
      ..add(vertices[i + 1] - pLon);
    pLat = vertices[i];
    pLon = vertices[i + 1];
  }

  final out = File(outPath)..createSync(recursive: true);
  out.writeAsStringSync(
    jsonEncode({
      'attribution': '© OpenStreetMap contributors, ODbL 1.0',
      'generated': DateTime.now().toUtc().toIso8601String(),
      'bbox': bbox,
      'format': 'v: delta-encoded lat,lon ×1e5; e: a,b,flags,class',
      'v': delta,
      'e': edges,
    }),
  );

  stdout
    ..writeln('Ways used: $ways, skipped: $skippedWays')
    ..writeln('Vertices: ${vertices.length ~/ 2}, edges: ${edges.length ~/ 4}')
    ..writeln(
      'Written $outPath '
      '(${(out.lengthSync() / 1024).toStringAsFixed(0)} KB)',
    );
}
