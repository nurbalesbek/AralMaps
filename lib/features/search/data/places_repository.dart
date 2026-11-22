import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/place.dart';
import '../domain/place_search.dart';

/// Named places of Aral from OpenStreetMap, bundled with the app so search
/// works offline. Regenerate with `dart run tool/fetch_places.dart`.
const placesAsset = 'assets/data/aral_places.json';

final placesProvider = FutureProvider<List<Place>>((ref) async {
  final raw = await rootBundle.loadString(placesAsset);
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final p in (json['places'] as List).cast<Map<String, dynamic>>())
      Place.fromJson(p),
  ];
});

final placeSearchProvider = FutureProvider<PlaceSearch>(
  (ref) async => PlaceSearch(await ref.watch(placesProvider.future)),
);
