/// Whether the map of Aral is stored on the device for offline use.
sealed class OfflineMapState {
  const OfflineMapState();
}

/// Not known yet (reading the offline database at startup).
final class OfflineMapChecking extends OfflineMapState {
  const OfflineMapChecking();
}

final class OfflineMapNotDownloaded extends OfflineMapState {
  const OfflineMapNotDownloaded();
}

final class OfflineMapDownloading extends OfflineMapState {
  const OfflineMapDownloading({required this.progress, required this.bytes});

  /// 0.0 – 1.0
  final double progress;
  final int bytes;
}

final class OfflineMapReady extends OfflineMapState {
  const OfflineMapReady({required this.bytes});

  final int bytes;
}

final class OfflineMapFailed extends OfflineMapState {
  const OfflineMapFailed(this.message);

  final String message;
}

String formatMegabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb < 10 ? '${mb.toStringAsFixed(1)} МБ' : '${mb.round()} МБ';
}
