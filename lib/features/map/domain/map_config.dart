import 'package:maplibre_gl/maplibre_gl.dart';

/// Static map settings for Aral (Аральск).
abstract final class MapConfig {
  /// OpenFreeMap "Liberty" style: OpenStreetMap data, free, no API key.
  /// Needs internet. Offline tiles replace it in a later phase.
  static const styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  /// Aral city centre (46°48′N 61°40′E).
  static const aralCenter = LatLng(46.800, 61.667);
  static const cityZoom = 13.0;

  static const initialCamera = CameraPosition(
    target: aralCenter,
    zoom: cityZoom,
  );

  /// Required by the ODbL and the tile provider; must stay visible.
  static const attribution =
      '© OpenFreeMap © OpenMapTiles © OpenStreetMap contributors';

  /// If the style has not loaded by then, show an error instead of a blank map.
  static const loadTimeout = Duration(seconds: 20);
}
