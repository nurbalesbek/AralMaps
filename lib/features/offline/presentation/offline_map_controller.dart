import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offline_map_service.dart';
import '../domain/offline_map_state.dart';

final offlineMapServiceProvider = Provider<OfflineMapService>(
  (ref) => MapLibreOfflineMapService(),
);

final offlineMapProvider =
    NotifierProvider<OfflineMapController, OfflineMapState>(
      OfflineMapController.new,
    );

class OfflineMapController extends Notifier<OfflineMapState> {
  OfflineMapService get _service => ref.read(offlineMapServiceProvider);

  @override
  OfflineMapState build() {
    _check();
    return const OfflineMapChecking();
  }

  Future<void> _check() async {
    try {
      final bytes = await _service.storedBytes();
      state = bytes == null
          ? const OfflineMapNotDownloaded()
          : OfflineMapReady(bytes: bytes);
    } on PlatformException {
      state = const OfflineMapNotDownloaded();
    }
  }

  Future<void> download() async {
    if (state is OfflineMapDownloading) return;
    state = const OfflineMapDownloading(progress: 0, bytes: 0);
    try {
      await _service.download(
        onProgress: (p) {
          state = OfflineMapDownloading(
            progress: p.required == 0 ? 0 : p.completed / p.required,
            bytes: p.bytes,
          );
        },
      );
      await _check();
    } on PlatformException catch (e) {
      state = OfflineMapFailed(_messageFor(e.code));
    } catch (_) {
      state = const OfflineMapFailed(
        'Не удалось скачать карту. Попробуйте ещё раз.',
      );
    }
  }

  Future<void> delete() async {
    await _service.delete();
    state = const OfflineMapNotDownloaded();
  }

  static String _messageFor(String code) => switch (code) {
    'TILE_COUNT_LIMIT_EXCEEDED' =>
      'Область карты слишком большая для скачивания.',
    'REGION_DELETED' || 'DATABASE_RESET' => 'Скачивание было отменено.',
    _ => 'Не удалось скачать карту. Попробуйте ещё раз.',
  };
}
