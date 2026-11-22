import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../search/domain/place.dart';

/// Sync bookkeeping kept next to the local favorites.
class SyncMeta {
  const SyncMeta({this.userId, this.dirty = false});

  /// The account these local favorites were last synced with.
  final String? userId;

  /// Local changes not yet sent to the cloud (e.g. made offline).
  final bool dirty;
}

/// Saved places, stored on the device. An interface so tests use memory.
abstract interface class FavoritesRepository {
  Future<List<Place>> load();
  Future<void> save(List<Place> places);
  Future<SyncMeta> loadMeta();
  Future<void> saveMeta(SyncMeta meta);
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => SharedPreferencesFavoritesRepository(),
);

class SharedPreferencesFavoritesRepository implements FavoritesRepository {
  /// Bump the version if the stored format changes incompatibly.
  static const _key = 'favorites.v1';
  static const _metaUser = 'favorites.sync.user';
  static const _metaDirty = 'favorites.sync.dirty';

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

  @override
  Future<SyncMeta> loadMeta() async => SyncMeta(
    userId: await _prefs.getString(_metaUser),
    dirty: await _prefs.getBool(_metaDirty) ?? false,
  );

  @override
  Future<void> saveMeta(SyncMeta meta) async {
    final user = meta.userId;
    if (user == null) {
      await _prefs.remove(_metaUser);
    } else {
      await _prefs.setString(_metaUser, user);
    }
    await _prefs.setBool(_metaDirty, meta.dirty);
  }
}
