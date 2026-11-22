import 'dart:convert';
import 'dart:io';

import 'package:aralmap/features/routing/domain/road_graph.dart';
import 'package:flutter_test/flutter_test.dart';

/// Encodes absolute lat/lon ×1e5 the way tool/fetch_roads.dart does.
List<int> _delta(List<(int, int)> points) {
  final out = <int>[];
  var pa = 0, pb = 0;
  for (final (a, b) in points) {
    out
      ..add(a - pa)
      ..add(b - pb);
    pa = a;
    pb = b;
  }
  return out;
}

// Flags and classes as in the tool.
const foot = 1, fwd = 2, back = 4, both = foot | fwd | back;
const residential = 6, path = 10;

/// A small square block, ~110 m per side:
///
///   0 ──── 1
///   │      │
///   3 ──── 2
///
/// 0→1→2 is a normal street, 2→3 is one-way (only 2→3 by car),
/// 3─0 is a footpath (no cars).
final _square = RoadGraph.fromEncoded(
  vertices: _delta([
    (4680000, 6166000), // 0
    (4680000, 6166150), // 1
    (4679900, 6166150), // 2
    (4679900, 6166000), // 3
  ]),
  edges: [
    0, 1, both, residential, //
    1, 2, both, residential,
    2, 3, foot | fwd, residential,
    3, 0, foot, path,
  ],
);

GeoPoint _v(int lat, int lon) => (lat: lat / 1e5, lon: lon / 1e5);

void main() {
  group('RoadGraph', () {
    test('walking takes the short footpath 0→3', () {
      final r = _square.route(
        _v(4680000, 6166000),
        _v(4679900, 6166000),
        TravelMode.walk,
      );
      expect(r, isA<RouteFound>());
      final found = r as RouteFound;
      expect(found.distanceMeters, closeTo(111, 3)); // 0.001° lat
    });

    test('driving 0→3 goes around the block (footpath is closed to cars)', () {
      final r = _square.route(
        _v(4680000, 6166000),
        _v(4679900, 6166000),
        TravelMode.drive,
      ) as RouteFound;
      // 0→1 (~115 m) + 1→2 (~111 m) + 2→3 (~115 m)
      expect(r.distanceMeters, closeTo(341, 8));
      expect(r.points.length, 6); // exact start, 4 vertices, exact end
    });

    test('a car goes around a one-way street; a pedestrian does not', () {
      // Same square, all streets: 1→2 is one-way, the rest two-way.
      final ring = RoadGraph.fromEncoded(
        vertices: _delta([
          (4680000, 6166000), // 0
          (4680000, 6166150), // 1
          (4679900, 6166150), // 2
          (4679900, 6166000), // 3
        ]),
        edges: [
          0, 1, both, residential, //
          1, 2, foot | fwd, residential,
          2, 3, both, residential,
          3, 0, both, residential,
        ],
      );
      final at2 = _v(4679900, 6166150), at1 = _v(4680000, 6166150);

      final drive = ring.route(at2, at1, TravelMode.drive) as RouteFound;
      // 2→3 (~115 m) + 3→0 (~111 m) + 0→1 (~115 m), not 2→1 (~111 m).
      expect(drive.distanceMeters, closeTo(341, 8));

      final walk = ring.route(at2, at1, TravelMode.walk) as RouteFound;
      expect(walk.distanceMeters, closeTo(111, 3));
    });

    test('a point far from every road is reported, with its distance', () {
      final r = _square.route(
        _v(4700000, 6166000), // ~22 km north
        _v(4680000, 6166000),
        TravelMode.walk,
      );
      expect(r, isA<RouteNotFound>());
      final nf = r as RouteNotFound;
      expect(nf.reason, RouteFailure.startOffNetwork);
      expect(nf.startDistanceMeters, greaterThan(20000));
    });

    test('destination off the network', () {
      final r = _square.route(
        _v(4680000, 6166000),
        _v(4680000, 6200000),
        TravelMode.walk,
      );
      expect((r as RouteNotFound).reason, RouteFailure.endOffNetwork);
    });

    test('unconnected pieces give noPath', () {
      final g = RoadGraph.fromEncoded(
        vertices: _delta([
          (4680000, 6166000),
          (4680000, 6166100),
          (4680100, 6166000),
          (4680100, 6166100),
        ]),
        edges: [0, 1, both, residential, 2, 3, both, residential],
      );
      final r = g.route(
        _v(4680000, 6166000),
        _v(4680100, 6166100),
        TravelMode.walk,
      );
      expect((r as RouteNotFound).reason, RouteFailure.noPath);
    });
  });

  group('formatting', () {
    test('distance', () {
      expect(formatDistance(84), '80 м');
      expect(formatDistance(1234), '1,2 км');
    });

    test('duration', () {
      expect(formatDuration(30), '1 мин');
      expect(formatDuration(25 * 60), '25 мин');
      expect(formatDuration(95 * 60), '1 ч 35 мин');
    });
  });

  test('bundled Aral road data routes across town in both modes', () {
    final json = jsonDecode(
      File('assets/data/aral_roads.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final graph = RoadGraph.fromEncoded(
      vertices: (json['v'] as List).cast<int>(),
      edges: (json['e'] as List).cast<int>(),
    );
    expect(graph.vertexCount, greaterThan(1000));

    // Railway station area → south of the centre, ~2 km apart.
    const a = (lat: 46.7990, lon: 61.6650);
    const b = (lat: 46.7830, lon: 61.6560);
    for (final mode in TravelMode.values) {
      final r = graph.route(a, b, mode);
      expect(r, isA<RouteFound>(), reason: '$mode');
      final found = r as RouteFound;
      // Along roads it can't be shorter than the straight line.
      expect(found.distanceMeters, greaterThan(distanceMeters(a, b)));
      expect(found.distanceMeters, lessThan(distanceMeters(a, b) * 3));
    }
  });
}
