import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/location_result.dart';

/// Device location access. An interface so widget tests can fake it.
abstract interface class LocationService {
  /// True if permission is already granted. Never shows a prompt.
  Future<bool> hasPermission();

  /// Asks for permission if needed, then gets the current position.
  Future<LocationResult> locate();

  Future<void> openAppSettings();

  Future<void> openLocationSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

class GeolocatorLocationService implements LocationService {
  static const _fixTimeout = Duration(seconds: 15);

  static bool _isGranted(LocationPermission p) =>
      p == LocationPermission.whileInUse || p == LocationPermission.always;

  @override
  Future<bool> hasPermission() async =>
      _isGranted(await Geolocator.checkPermission());

  @override
  Future<LocationResult> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationFailed(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationFailed(LocationFailure.deniedForever);
    }
    if (!_isGranted(permission)) {
      return const LocationFailed(LocationFailure.denied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
      return _found(position);
    } on TimeoutException {
      // Indoors a fresh fix may not arrive; a recent one is better than none.
      final last = await Geolocator.getLastKnownPosition();
      return last != null
          ? _found(last)
          : const LocationFailed(LocationFailure.unavailable);
    } on LocationServiceDisabledException {
      return const LocationFailed(LocationFailure.serviceDisabled);
    }
  }

  static LocationFound _found(Position p) => LocationFound(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyMeters: p.accuracy,
  );

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
