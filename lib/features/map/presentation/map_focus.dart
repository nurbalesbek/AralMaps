import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../search/domain/place.dart';

/// A request from another tab (e.g. Favorites) to show a place on the map,
/// optionally with a route to it. The map consumes and clears it.
class MapFocusRequest {
  const MapFocusRequest(this.place, {this.withRoute = false});

  final Place place;
  final bool withRoute;
}

final mapFocusProvider = NotifierProvider<MapFocusController, MapFocusRequest?>(
  MapFocusController.new,
);

class MapFocusController extends Notifier<MapFocusRequest?> {
  @override
  MapFocusRequest? build() => null;

  void request(Place place, {bool withRoute = false}) =>
      state = MapFocusRequest(place, withRoute: withRoute);

  void clear() => state = null;
}
