import 'dart:math' as math;

import 'package:collection/collection.dart';

typedef GeoPoint = ({double lat, double lon});

enum TravelMode {
  walk('Пешком'),
  drive('На машине');

  const TravelMode(this.label);
  final String label;
}

sealed class RouteResult {
  const RouteResult();
}

final class RouteFound extends RouteResult {
  const RouteFound({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// From the exact start to the exact destination, along the roads.
  final List<GeoPoint> points;
  final double distanceMeters;
  final double durationSeconds;
}

enum RouteFailure {
  /// The start is too far from any road of the town.
  startOffNetwork,

  /// The destination is too far from any road of the town.
  endOffNetwork,

  /// Both are on the network, but not connected for this mode
  /// (e.g. a one-way street, or a separate road piece).
  noPath,
}

final class RouteNotFound extends RouteResult {
  const RouteNotFound(this.reason, {this.startDistanceMeters});

  final RouteFailure reason;

  /// How far the start is from the nearest road (for [startOffNetwork]).
  final double? startDistanceMeters;
}

/// Edge flags, same values as tool/fetch_roads.dart.
const _foot = 1, _carForward = 2, _carBackward = 4;

/// km/h by road class index (see `roadClasses` in tool/fetch_roads.dart).
/// Town driving, so well below legal limits.
const _driveSpeedKmh = <double>[90, 80, 60, 50, 40, 30, 30, 10, 15, 15, 0];
const _walkSpeedKmh = 4.5;

/// Connector between an exact point and its nearest road vertex.
const _connectorKmh = _walkSpeedKmh;

/// Points farther than this from every road are "off the network".
const maxSnapMeters = 500.0;

typedef _Arc = ({int to, double seconds, double meters});

/// Routing graph of the town's roads. Built once from the bundled data.
class RoadGraph {
  /// [vertices] is flat `lat, lon` ×1e5 delta-encoded; [edges] is flat
  /// `a, b, flags, class` (the format written by tool/fetch_roads.dart).
  factory RoadGraph.fromEncoded({
    required List<int> vertices,
    required List<int> edges,
  }) {
    final n = vertices.length ~/ 2;
    final lat = List<double>.filled(n, 0);
    final lon = List<double>.filled(n, 0);
    var a = 0, b = 0;
    for (var i = 0; i < n; i++) {
      a += vertices[2 * i];
      b += vertices[2 * i + 1];
      lat[i] = a / 1e5;
      lon[i] = b / 1e5;
    }

    final walk = List.generate(n, (_) => <_Arc>[]);
    final drive = List.generate(n, (_) => <_Arc>[]);
    for (var i = 0; i + 3 < edges.length; i += 4) {
      final from = edges[i], to = edges[i + 1];
      final flags = edges[i + 2], roadClass = edges[i + 3];
      final meters = distanceMeters(
        (lat: lat[from], lon: lon[from]),
        (lat: lat[to], lon: lon[to]),
      );
      if (flags & _foot != 0) {
        final s = _seconds(meters, _walkSpeedKmh);
        walk[from].add((to: to, seconds: s, meters: meters));
        walk[to].add((to: from, seconds: s, meters: meters));
      }
      final speed = _driveSpeedKmh[roadClass];
      if (speed > 0) {
        final s = _seconds(meters, speed);
        if (flags & _carForward != 0) {
          drive[from].add((to: to, seconds: s, meters: meters));
        }
        if (flags & _carBackward != 0) {
          drive[to].add((to: from, seconds: s, meters: meters));
        }
      }
    }
    return RoadGraph._(lat, lon, walk, drive);
  }

  RoadGraph._(this._lat, this._lon, this._walk, this._drive)
    : _driveIn = _incoming(_drive),
      _walkIn = _incoming(_walk);

  static List<bool> _incoming(List<List<_Arc>> arcs) {
    final into = List<bool>.filled(arcs.length, false);
    for (final list in arcs) {
      for (final a in list) {
        into[a.to] = true;
      }
    }
    return into;
  }

  final List<double> _lat;
  final List<double> _lon;
  final List<List<_Arc>> _walk;
  final List<List<_Arc>> _drive;

  /// Whether a vertex can be reached (for snapping the destination: the end
  /// of a one-way street can be arrived at, though not left).
  final List<bool> _walkIn;
  final List<bool> _driveIn;

  int get vertexCount => _lat.length;

  List<List<_Arc>> _arcs(TravelMode mode) =>
      mode == TravelMode.walk ? _walk : _drive;

  GeoPoint _point(int v) => (lat: _lat[v], lon: _lon[v]);

  /// Nearest vertex one can leave ([asStart]) or arrive at in [mode], or
  /// null if there is none. Linear scan: a few thousand vertices take well
  /// under a millisecond.
  ({int vertex, double meters})? _nearest(
    GeoPoint p,
    TravelMode mode, {
    required bool asStart,
  }) {
    final out = _arcs(mode);
    final into = mode == TravelMode.walk ? _walkIn : _driveIn;
    int? best;
    var bestMeters = double.infinity;
    for (var v = 0; v < _lat.length; v++) {
      if (asStart ? out[v].isEmpty : !into[v]) continue;
      final d = distanceMeters(p, _point(v));
      if (d < bestMeters) {
        bestMeters = d;
        best = v;
      }
    }
    return best == null ? null : (vertex: best, meters: bestMeters);
  }

  RouteResult route(GeoPoint from, GeoPoint to, TravelMode mode) {
    final start = _nearest(from, mode, asStart: true);
    if (start == null || start.meters > maxSnapMeters) {
      return RouteNotFound(
        RouteFailure.startOffNetwork,
        startDistanceMeters: start?.meters,
      );
    }
    final end = _nearest(to, mode, asStart: false);
    if (end == null || end.meters > maxSnapMeters) {
      return const RouteNotFound(RouteFailure.endOffNetwork);
    }

    final path = _aStar(start.vertex, end.vertex, mode);
    if (path == null) return const RouteNotFound(RouteFailure.noPath);

    final points = <GeoPoint>[from, for (final v in path) _point(v), to];
    var meters = start.meters + end.meters;
    var seconds =
        _seconds(start.meters, _connectorKmh) +
        _seconds(end.meters, _connectorKmh);
    final arcs = _arcs(mode);
    for (var i = 0; i + 1 < path.length; i++) {
      final arc = arcs[path[i]].firstWhere((a) => a.to == path[i + 1]);
      meters += arc.meters;
      seconds += arc.seconds;
    }
    return RouteFound(
      points: points,
      distanceMeters: meters,
      durationSeconds: seconds,
    );
  }

  /// Fastest path by travel time. Null if unreachable.
  List<int>? _aStar(int start, int goal, TravelMode mode) {
    if (start == goal) return [start];
    final arcs = _arcs(mode);
    final maxKmh = mode == TravelMode.walk
        ? _walkSpeedKmh
        : _driveSpeedKmh.reduce(math.max);
    final goalPoint = _point(goal);
    double h(int v) => _seconds(distanceMeters(_point(v), goalPoint), maxKmh);

    final cost = <int, double>{start: 0};
    final cameFrom = <int, int>{};
    final open = PriorityQueue<(double, int)>((a, b) => a.$1.compareTo(b.$1))
      ..add((h(start), start));

    while (open.isNotEmpty) {
      final (_, v) = open.removeFirst();
      if (v == goal) {
        final path = [goal];
        for (var prev = cameFrom[goal]; prev != null; prev = cameFrom[prev]) {
          path.add(prev);
        }
        return path.reversed.toList();
      }
      final base = cost[v]!;
      for (final arc in arcs[v]) {
        final next = base + arc.seconds;
        if (next < (cost[arc.to] ?? double.infinity)) {
          cost[arc.to] = next;
          cameFrom[arc.to] = v;
          open.add((next + h(arc.to), arc.to));
        }
      }
    }
    return null;
  }
}

double _seconds(double meters, double kmh) => meters / (kmh / 3.6);

/// Great-circle distance (haversine).
double distanceMeters(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLon = rad(b.lon - a.lon);
  final s =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(s));
}

String formatDistance(double meters) => meters < 1000
    ? '${(meters / 10).round() * 10} м'
    : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} км';

String formatDuration(double seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes мин';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h ч' : '$h ч $m мин';
}
