import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../search/domain/place.dart';

/// The user's favorites in the cloud (table user_favorites, one row per
/// user — see supabase/schema.sql).
abstract interface class RemoteFavorites {
  /// Null if the user has nothing stored yet.
  Future<List<Place>?> fetch(String userId);
  Future<void> push(String userId, List<Place> places);
}

final remoteFavoritesProvider = Provider<RemoteFavorites?>(
  (ref) => AppConfig.accountsEnabled
      ? SupabaseRemoteFavorites(sb.Supabase.instance.client)
      : null,
);

class SupabaseRemoteFavorites implements RemoteFavorites {
  SupabaseRemoteFavorites(this._client);

  final sb.SupabaseClient _client;
  static const _table = 'user_favorites';

  @override
  Future<List<Place>?> fetch(String userId) async {
    final row = await _client
        .from(_table)
        .select('places')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return [
      for (final p in (row['places'] as List).cast<Map<String, dynamic>>())
        Place.fromJson(p),
    ];
  }

  @override
  Future<void> push(String userId, List<Place> places) =>
      _client.from(_table).upsert({
        'user_id': userId,
        'places': [for (final p in places) p.toJson()],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
}
