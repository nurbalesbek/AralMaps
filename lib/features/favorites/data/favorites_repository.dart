import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../search/domain/place.dart';

/// Saved places, stored on the device. An interface so tests use memory.
abstract interface class FavoritesRepository {
  Future<List<Place>> load();
  Future<void> save(List<Place> places);
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => SharedPreferencesFavoritesRepository(),
);

class SharedPreferencesFavoritesRepository implements FavoritesRepository {
  /// Bump the version if the stored format changes incompatibly.
  static const _key = 'favorites.v1';

  final _prefs = SharedPreferencesAsync();

  @override
  Future<List<Place>> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final p in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          Place.fromJson(p),
      ];
    } on FormatException {
      return const []; // corrupted: start over rather than crash
    } on TypeError {
      return const [];
    }
  }

  @override
  Future<void> save(List<Place> places) =>
      _prefs.setString(_key, jsonEncode([for (final p in places) p.toJson()]));
}
