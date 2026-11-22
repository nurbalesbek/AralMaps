import '../../search/domain/place.dart';
import '../domain/road_graph.dart';

sealed class RouteOrigin {
  const RouteOrigin();
}

final class FromMyLocation extends RouteOrigin {
  const FromMyLocation();
}

final class FromPlace extends RouteOrigin {
  const FromPlace(this.place);
  final Place place;
}

/// A route being shown on the map: where to, from where, how, and the
/// outcome of the last calculation.
class RouteSession {
  const RouteSession({
    required this.destination,
    this.origin = const FromMyLocation(),
    this.mode = TravelMode.walk,
    this.computing = false,
    this.result,
    this.locationFailed = false,
  });

  final Place destination;
  final RouteOrigin origin;
  final TravelMode mode;
  final bool computing;

  /// Null while computing, or before the first calculation.
  final RouteResult? result;

  /// "From my location" was chosen but the location could not be obtained.
  final bool locationFailed;

  /// Starts a new calculation (clears the previous outcome).
  RouteSession computingWith({RouteOrigin? origin, TravelMode? mode}) =>
      RouteSession(
        destination: destination,
        origin: origin ?? this.origin,
        mode: mode ?? this.mode,
        computing: true,
      );

  RouteSession withResult(RouteResult result) => RouteSession(
    destination: destination,
    origin: origin,
    mode: mode,
    result: result,
  );

  RouteSession withLocationFailed() => RouteSession(
    destination: destination,
    origin: origin,
    mode: mode,
    locationFailed: true,
  );
}
