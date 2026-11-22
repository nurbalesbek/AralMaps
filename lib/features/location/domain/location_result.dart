/// Why the device location could not be obtained.
enum LocationFailure {
  /// GPS / location services are switched off on the device.
  serviceDisabled,

  /// The user declined the permission prompt (can be asked again).
  denied,

  /// The user blocked the permission; only the system settings can undo it.
  deniedForever,

  /// Permission is fine, but no fix arrived in time.
  unavailable,
}

sealed class LocationResult {
  const LocationResult();
}

final class LocationFound extends LocationResult {
  const LocationFound({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

final class LocationFailed extends LocationResult {
  const LocationFailed(this.reason);

  final LocationFailure reason;
}
