import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/road_graph.dart';

/// Road network of Aral from OpenStreetMap, bundled so routing works
/// offline. Regenerate with `dart run tool/fetch_roads.dart`.
const roadsAsset = 'assets/data/aral_roads.json';

final roadGraphProvider = FutureProvider<RoadGraph>((ref) async {
  final raw = await rootBundle.loadString(roadsAsset);
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return RoadGraph.fromEncoded(
    vertices: (json['v'] as List).cast<int>(),
    edges: (json['e'] as List).cast<int>(),
  );
});
