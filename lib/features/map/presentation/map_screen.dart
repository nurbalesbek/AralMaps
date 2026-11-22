import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../../location/data/location_service.dart';
import '../../location/domain/location_result.dart';
import '../domain/map_config.dart';
import 'widgets/map_view.dart';

enum _MapStatus { loading, ready, failed }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? _controller;
  _MapStatus _status = _MapStatus.loading;
  Timer? _loadTimeout;

  /// Changing the key recreates the native map (used by "retry").
  Key _mapKey = UniqueKey();

  /// Shows the blue dot. Only true once location permission is granted.
  bool _myLocationEnabled = false;
  bool _locating = false;

  static const _myLocationZoom = 16.0;

  @override
  void initState() {
    super.initState();
    _startLoadTimeout();
    _restoreLocationDot();
  }

  /// If permission was granted earlier, show the dot right away
  /// (without prompting; the prompt only comes from the button).
  Future<void> _restoreLocationDot() async {
    final granted = await ref.read(locationServiceProvider).hasPermission();
    if (granted && mounted) setState(() => _myLocationEnabled = true);
  }

  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final service = ref.read(locationServiceProvider);
    final result = await service.locate();
    if (!mounted) return;
    setState(() => _locating = false);

    switch (result) {
      case LocationFound(:final latitude, :final longitude):
        setState(() => _myLocationEnabled = true);
        await _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(latitude, longitude),
            _myLocationZoom,
          ),
          duration: const Duration(milliseconds: 600),
        );
      case LocationFailed(:final reason):
        _showLocationError(reason, service);
    }
  }

  void _showLocationError(LocationFailure reason, LocationService service) {
    final (message, action) = switch (reason) {
      LocationFailure.serviceDisabled => (
        'Геолокация выключена на телефоне',
        SnackBarAction(
          label: 'Включить',
          onPressed: service.openLocationSettings,
        ),
      ),
      LocationFailure.denied => (
        'Без доступа к геолокации нельзя показать, где вы',
        null,
      ),
      LocationFailure.deniedForever => (
        'Доступ к геолокации запрещён. Разрешите его в настройках',
        SnackBarAction(label: 'Настройки', onPressed: service.openAppSettings),
      ),
      LocationFailure.unavailable => (
        'Не удалось определить местоположение. Попробуйте на открытом месте',
        null,
      ),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    super.dispose();
  }

  void _startLoadTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(MapConfig.loadTimeout, () {
      if (mounted && _status == _MapStatus.loading) {
        setState(() => _status = _MapStatus.failed);
      }
    });
  }

  void _onStyleLoaded() {
    _loadTimeout?.cancel();
    if (mounted) setState(() => _status = _MapStatus.ready);
  }

  void _retry() {
    setState(() {
      _controller = null;
      _status = _MapStatus.loading;
      _mapKey = UniqueKey();
    });
    _startLoadTimeout();
  }

  Future<void> _recenter() async {
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(MapConfig.initialCamera),
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buildMapView = ref.watch(mapViewBuilderProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: buildMapView(
              key: _mapKey,
              onMapCreated: (controller) => _controller = controller,
              onStyleLoaded: _onStyleLoaded,
              myLocationEnabled: _myLocationEnabled,
            ),
          ),
          if (_status == _MapStatus.loading)
            const _StatusCard(
              key: ValueKey('map-loading'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  SizedBox(width: 12),
                  Text('Загрузка карты…'),
                ],
              ),
            ),
          if (_status == _MapStatus.failed)
            _StatusCard(
              key: const ValueKey('map-failed'),
              child: _LoadError(onRetry: _retry),
            ),
          const _Attribution(),
        ],
      ),
      floatingActionButton: _status == _MapStatus.ready
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter-city',
                  onPressed: _recenter,
                  tooltip: 'Показать Аральск',
                  child: const Icon(Icons.location_city),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'my-location',
                  onPressed: _locating ? null : _goToMyLocation,
                  tooltip: 'Где я',
                  child: _locating
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            )
          : null,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off, color: theme.colorScheme.error, size: 32),
        const SizedBox(height: 12),
        Text('Не удалось загрузить карту', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Проверьте подключение к интернету. Офлайн-карта появится позже.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    );
  }
}

/// Always-visible data attribution, required by the ODbL.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      right: 72,
      bottom: 6,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              MapConfig.attribution,
              style: TextStyle(fontSize: 10, color: Color(0xFF263238)),
            ),
          ),
        ),
      ),
    );
  }
}
