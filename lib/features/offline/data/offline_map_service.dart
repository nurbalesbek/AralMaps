import 'dart:async';

import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../map/domain/map_config.dart';

/// Progress of one download, as reported by MapLibre.
typedef OfflineProgress = ({int completed, int required, int bytes});

/// Stores the map of Aral in MapLibre's offline database. The map keeps
/// using the same style URL; MapLibre serves it from the database when there
/// is no network. An interface so tests can fake it.
abstract interface class OfflineMapService {
  /// Size in bytes if every region is fully stored, otherwise null.
  Future<int?> storedBytes();

  /// Downloads all regions. Completes when done; throws on failure.
  Future<void> download({required void Function(OfflineProgress) onProgress});

  Future<void> delete();
}

/// One area at one zoom range. The town needs street-level zooms; the
/// surroundings (Aral Sea, roads to other towns) only overview zooms.
typedef _Region = ({String id, ml.LatLngBounds bounds, double min, double max});

class MapLibreOfflineMapService implements OfflineMapService {
  static final List<_Region> _regions = [
    (
      id: 'aral-town',
      bounds: ml.LatLngBounds(
        southwest: const ml.LatLng(46.74, 61.57),
        northeast: const ml.LatLng(46.85, 61.76),
      ),
      min: 10,
      max: 16,
    ),
    (
      id: 'aral-surroundings',
      bounds: ml.LatLngBounds(
        southwest: const ml.LatLng(45.6, 59.8),
        northeast: const ml.LatLng(47.6, 62.6),
      ),
      min: 4,
      max: 10,
    ),
  ];

  static const _metadataKey = 'aralmap_region';

  /// Our regions currently in the database, by id.
  Future<Map<String, ml.OfflineRegion>> _stored() async {
    final all = await ml.getListOfRegions();
    return {
      for (final r in all)
        if (r.metadata[_metadataKey] case final String id) id: r,
    };
  }

  @override
  Future<int?> storedBytes() async {
    final stored = await _stored();
    if (stored.length != _regions.length) return null;
    var bytes = 0;
    for (final region in stored.values) {
      final status = await ml.getOfflineRegionStatus(region.id);
      if (!status.isComplete) return null;
      bytes += status.completedResourceSize;
    }
    return bytes;
  }

  @override
  Future<void> download({
    required void Function(OfflineProgress) onProgress,
  }) async {
    // Start clean: a half-finished region from a killed app would otherwise
    // be counted as stored.
    await delete();
    // MapLibre's default cap (6000 tiles) is close to what the two regions
    // need; raise it so the download does not fail near the end.
    await ml.setOfflineTileCountLimit(20000);

    var bytesBefore = 0;
    for (final (i, region) in _regions.indexed) {
      final result = await _downloadOne(region, (p) {
        onProgress((
          completed: i * 1000 + _permille(p.completed, p.required),
          required: _regions.length * 1000,
          bytes: bytesBefore + p.bytes,
        ));
      });
      bytesBefore += result;
    }
  }

  static int _permille(int done, int total) =>
      total == 0 ? 0 : (done * 1000 ~/ total).clamp(0, 1000);

  /// Returns the stored size of the region.
  Future<int> _downloadOne(
    _Region region,
    void Function(OfflineProgress) onProgress,
  ) {
    var bytes = 0;
    final done = _OnceCompleter<int>();
    final started = ml.downloadOfflineRegion(
      ml.OfflineRegionDefinition(
        bounds: region.bounds,
        mapStyleUrl: MapConfig.styleUrl,
        minZoom: region.min,
        maxZoom: region.max,
      ),
      metadata: {_metadataKey: region.id},
      onEvent: (event) {
        switch (event) {
          case ml.InProgress():
            bytes = event.completedResourceSize;
            onProgress((
              completed: event.completedResourceCount,
              required: event.requiredResourceCount,
              bytes: bytes,
            ));
          case ml.Success():
            done.complete(bytes);
          case ml.Error():
            done.completeError(event.cause);
        }
      },
    );
    // The call itself fails for an invalid definition; events report the rest.
    unawaited(started.then<void>((_) {}, onError: done.completeError));
    return done.future;
  }

  @override
  Future<void> delete() async {
    for (final region in (await _stored()).values) {
      try {
        await ml.deleteOfflineRegion(region.id);
      } on PlatformException {
        // Already gone.
      }
    }
  }
}

/// Completes once; later events (e.g. a late one after an error) are ignored
/// instead of throwing "Future already completed".
class _OnceCompleter<T> {
  final _c = Completer<T>();
  Future<T> get future => _c.future;

  void complete(T value) {
    if (!_c.isCompleted) _c.complete(value);
  }

  void completeError(Object error) {
    if (!_c.isCompleted) _c.completeError(error);
  }
}
