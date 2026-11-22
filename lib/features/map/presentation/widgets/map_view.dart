import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/map_config.dart';

typedef MapViewBuilder = Widget Function({
  Key? key,
  required void Function(MapLibreMapController controller) onMapCreated,
  required VoidCallback onStyleLoaded,
  required bool myLocationEnabled,
});

/// Builds the native map. Overridden in widget tests, where platform views
/// are not available.
final mapViewBuilderProvider = Provider<MapViewBuilder>(
  (ref) => _buildMapLibreView,
);

Widget _buildMapLibreView({
  Key? key,
  required void Function(MapLibreMapController controller) onMapCreated,
  required VoidCallback onStyleLoaded,
  required bool myLocationEnabled,
}) {
  return MapLibreMap(
    key: key,
    styleString: MapConfig.styleUrl,
    initialCameraPosition: MapConfig.initialCamera,
    onMapCreated: onMapCreated,
    onStyleLoadedCallback: onStyleLoaded,
    compassEnabled: true,
    // MapScreen shows the attribution as always-visible text, so the native
    // "i" button is redundant (and overlapped that text).
    attributionEnabled: false,
    // Blue dot. Must only be true once location permission is granted,
    // otherwise the native location component fails.
    myLocationEnabled: myLocationEnabled,
  );
}
