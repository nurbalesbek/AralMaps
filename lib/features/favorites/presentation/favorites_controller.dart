import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/data/auth_service.dart';
import '../../search/domain/place.dart';
import '../data/favorites_repository.dart';
import '../data/remote_favorites.dart';

enum FavoritesSync {
  /// Not signed in: favorites live on this phone only.
  localOnly,
  syncing,
  synced,

  /// Signed in, but the last attempt failed (usually no internet).
  /// Changes are kept and sent on the next attempt.
  pending,
}

final favoritesSyncProvider =
    NotifierProvider<FavoritesSyncStatus, FavoritesSync>(
      FavoritesSyncStatus.new,
    );

class FavoritesSyncStatus extends Notifier<FavoritesSync> {
  @override
  FavoritesSync build() => FavoritesSync.localOnly;

  void set(FavoritesSync value) => state = value;
}

/// Saved places, newest first. Stored on the phone; when signed in, also
/// in the account (see [_sync] for the rules).
final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, List<Place>>(
      FavoritesController.new,
    );

class FavoritesController extends AsyncNotifier<List<Place>> {
  FavoritesRepository get _local => ref.read(favoritesRepositoryProvider);
  RemoteFavorites? get _remote => ref.read(remoteFavoritesProvider);

  void _setSync(FavoritesSync s) =>
      ref.read(favoritesSyncProvider.notifier).set(s);

  @override
  Future<List<Place>> build() async {
    // Rebuilds on sign-in / sign-out.
    final user = ref.watch(currentUserProvider);
    final places = await _local.load();
    if (user == null || _remote == null) {
      Future.microtask(() => _setSync(FavoritesSync.localOnly));
      return places;
    }
    return _sync(user, places);
  }

  /// - First sync of this account on this phone: merge phone and account
  ///   (nothing is lost), store the result in both.
  /// - Unsent local changes: send them (the phone wins).
  /// - Otherwise: take the account's version (changes from other phones).
  /// Offline: keep the local list and mark it pending.
  Future<List<Place>> _sync(AppUser user, List<Place> local) async {
    final remote = _remote!;
    Future.microtask(() => _setSync(FavoritesSync.syncing));
    final meta = await _local.loadMeta();
    try {
      final List<Place> result;
      if (meta.userId != user.id) {
        final cloud = await remote.fetch(user.id) ?? const [];
        result = [...local, ...cloud.where((p) => !local.contains(p))];
        await remote.push(user.id, result);
      } else if (meta.dirty) {
        await remote.push(user.id, local);
        result = local;
      } else {
        result = await remote.fetch(user.id) ?? local;
      }
      await _local.save(result);
      await _local.saveMeta(SyncMeta(userId: user.id));
      Future.microtask(() => _setSync(FavoritesSync.synced));
      return result;
    } catch (_) {
      // Keep working offline. Meta is left as it was: a first-time merge
      // is retried next start, unsent changes stay unsent, and a failed
      // *download* must not mark the phone's list as newer than the cloud
      // (that would overwrite changes made on another phone).
      Future.microtask(() => _setSync(FavoritesSync.pending));
      return local;
    }
  }

  /// Saves locally, then tries to send to the account.
  Future<void> _store(List<Place> next) async {
    state = AsyncData(next);
    await _local.save(next);
    final user = ref.read(currentUserProvider);
    final remote = _remote;
    if (user == null || remote == null) return;

    final meta = await _local.loadMeta();
    if (meta.userId != user.id) return; // first merge not done yet
    await _local.saveMeta(SyncMeta(userId: user.id, dirty: true));
    _setSync(FavoritesSync.syncing);
    try {
      await remote.push(user.id, next);
      await _local.saveMeta(SyncMeta(userId: user.id));
      _setSync(FavoritesSync.synced);
    } catch (_) {
      _setSync(FavoritesSync.pending);
    }
  }

  /// Retry after "pending" (e.g. the user got internet back).
  Future<void> retrySync() async => ref.invalidateSelf();

  /// On sign-out / account deletion: the list stays in the account, but
  /// the next person using this phone must not see it.
  Future<void> clearLocal() async {
    // Let a running sync finish first; otherwise it would write the
    // account's list back to the phone after we cleared it.
    try {
      await future;
    } catch (_) {}
    await _local.save(const []);
    await _local.saveMeta(const SyncMeta());
    state = const AsyncData([]);
  }

  bool contains(Place place) => state.value?.contains(place) ?? false;

  Future<void> add(Place place, {int? at}) async {
    final current = await future;
    if (current.contains(place)) return;
    await _store([...current]..insert(at ?? 0, place));
  }

  /// Returns the index it had, so "Undo" can put it back in place.
  Future<int> remove(Place place) async {
    final current = await future;
    final index = current.indexOf(place);
    if (index < 0) return -1;
    await _store([...current]..removeAt(index));
    return index;
  }

  /// Adds or removes; returns true if the place is now saved.
  Future<bool> toggle(Place place) async {
    if ((await future).contains(place)) {
      await remove(place);
      return false;
    }
    await add(place);
    return true;
  }
}
