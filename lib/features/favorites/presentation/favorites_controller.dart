import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../search/domain/place.dart';
import '../data/favorites_repository.dart';

/// Saved places, newest first.
final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, List<Place>>(
      FavoritesController.new,
    );

class FavoritesController extends AsyncNotifier<List<Place>> {
  FavoritesRepository get _repo => ref.read(favoritesRepositoryProvider);

  @override
  Future<List<Place>> build() => _repo.load();

  bool contains(Place place) => state.value?.contains(place) ?? false;

  Future<void> add(Place place, {int? at}) async {
    final current = await future;
    if (current.contains(place)) return;
    final next = [...current]..insert(at ?? 0, place);
    state = AsyncData(next);
    await _repo.save(next);
  }

  /// Returns the index it had, so "Undo" can put it back in place.
  Future<int> remove(Place place) async {
    final current = await future;
    final index = current.indexOf(place);
    if (index < 0) return -1;
    final next = [...current]..removeAt(index);
    state = AsyncData(next);
    await _repo.save(next);
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
