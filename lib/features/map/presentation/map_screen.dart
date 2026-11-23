import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/category_avatar.dart';
import '../../../shared/widgets/map_controls.dart';
import '../../favorites/presentation/favorites_controller.dart';
import '../../location/data/location_service.dart';
import '../../location/domain/location_result.dart';
import '../../offline/presentation/offline_map_widgets.dart';
import '../../routing/data/road_graph_repository.dart';
import '../../routing/domain/road_graph.dart';
import '../../routing/presentation/route_panel.dart';
import '../../routing/presentation/route_session.dart';
import '../../search/data/places_repository.dart';
import '../../search/domain/place.dart';
import '../../tourism/data/sights.dart';
import '../../tourism/domain/sight.dart';
import '../domain/map_config.dart';
import 'map_focus.dart';
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
  static const _placeZoom = 17.0;

  /// "Later" on the offline-map prompt hides it until the next app start.
  bool _offlineBannerDismissed = false;

  /// Place picked in search, shown with a marker and a card.
  Place? _selectedPlace;
  Circle? _placeMarker;

  Future<void> _openSearch() async {
    final place = await context.push<Place>(AppRoutes.search);
    if (place != null && mounted) await _showPlace(place);
  }

  // ---- Routing -----------------------------------------------------------

  RouteSession? _route;
  Line? _routeLine;

  /// Bumped on every calculation, so a slow one (waiting for GPS) cannot
  /// overwrite a newer one (e.g. after switching mode).
  int _routeRequest = 0;

  /// Last position from "my location" during this route, so switching the
  /// mode does not wait for GPS again.
  GeoPoint? _routeFromCache;

  void _startRoute(Place destination) {
    _routeFromCache = null;
    _computeRoute(RouteSession(destination: destination).computingWith());
  }

  Future<void> _computeRoute(RouteSession session) async {
    final request = ++_routeRequest;
    setState(() => _route = session);
    await _removeRouteLine();

    GeoPoint? from;
    switch (session.origin) {
      case FromPlace(:final place):
        from = (lat: place.latitude, lon: place.longitude);
      case FromMyLocation():
        from = _routeFromCache;
        if (from == null) {
          final service = ref.read(locationServiceProvider);
          final located = await service.locate();
          if (!mounted || request != _routeRequest) return;
          switch (located) {
            case LocationFound(:final latitude, :final longitude):
              from = (lat: latitude, lon: longitude);
              _routeFromCache = from;
              setState(() => _myLocationEnabled = true);
            case LocationFailed(:final reason):
              _showLocationError(reason, service);
              setState(() => _route = session.withLocationFailed());
              return;
          }
        }
    }

    final graph = await ref.read(roadGraphProvider.future);
    if (!mounted || request != _routeRequest) return;
    final destination = session.destination;
    final result = graph.route(from, (
      lat: destination.latitude,
      lon: destination.longitude,
    ), session.mode);
    setState(() => _route = session.withResult(result));
    if (result is RouteFound) await _drawRoute(result);
  }

  Future<void> _drawRoute(RouteFound route) async {
    final controller = _controller;
    if (controller == null) return;
    final points = [for (final p in route.points) LatLng(p.lat, p.lon)];
    _routeLine = await controller.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#287E72',
        lineWidth: 6,
        lineOpacity: 0.9,
        lineJoin: 'round',
      ),
    );
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        // Keep the line clear of the search bar and the route panel.
        left: 40,
        right: 40,
        top: 140,
        bottom: 340,
      ),
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _removeRouteLine() async {
    final line = _routeLine;
    _routeLine = null;
    if (line != null) await _controller?.removeLine(line);
  }

  Future<void> _closeRoute() async {
    _routeRequest++; // cancel anything in flight
    setState(() => _route = null);
    await _removeRouteLine();
  }

  void _changeRouteMode(TravelMode mode) {
    final route = _route;
    if (route != null) _computeRoute(route.computingWith(mode: mode));
  }

  Future<void> _chooseRouteOrigin() async {
    final place = await context.push<Place>(
      AppRoutes.search,
      extra: 'Откуда идти?',
    );
    final route = _route;
    if (place == null || route == null || !mounted) return;
    await _computeRoute(route.computingWith(origin: FromPlace(place)));
  }

  void _routeFromMyLocation() {
    final route = _route;
    if (route != null) {
      _computeRoute(route.computingWith(origin: const FromMyLocation()));
    }
  }

  // ---- Places -------------------------------------------------------------

  Future<void> _openCategory(PlaceCategory category) async {
    final place = await context.push<Place>(
      AppRoutes.searchFor(category.label),
    );
    if (place != null && mounted) await _showPlace(place);
  }

  Future<void> _showPlace(Place place, {double? zoom}) async {
    if (_route != null) await _closeRoute();
    setState(() => _selectedPlace = place);
    final controller = _controller;
    if (controller == null) return;
    final position = LatLng(place.latitude, place.longitude);

    final oldMarker = _placeMarker;
    _placeMarker = null;
    if (oldMarker != null) await controller.removeCircle(oldMarker);
    _placeMarker = await controller.addCircle(
      CircleOptions(
        geometry: position,
        circleRadius: 11,
        circleColor: place.category.colorHex,
        circleStrokeWidth: 4,
        circleStrokeColor: '#FFFFFF',
      ),
    );
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(position, zoom ?? _placeZoom),
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _clearPlace() async {
    final marker = _placeMarker;
    setState(() {
      _selectedPlace = null;
      _placeMarker = null;
    });
    if (marker != null) await _controller?.removeCircle(marker);
  }

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
    _addPlaceDots();
  }

  /// Feature id (index) → place, for taps on the coloured dots.
  List<Place> _dotPlaces = const [];

  static const _dotsSource = 'aralmap-places';
  static const _dotLayer = 'aralmap-dots';

  /// Every named point of the town (cafés, pharmacies, schools…) and the
  /// located sights of the Explore tab, as dots in their category colour.
  /// Each dot is shown on its own (grouping was tried and turned off at
  /// the user's request).
  Future<void> _addPlaceDots() async {
    final controller = _controller;
    if (controller == null) return;
    final places = await ref.read(placesProvider.future);
    final dots = [
      for (final p in places)
        if (p.category.showOnMap) p,
      for (final s in sights)
        if (s.hasLocation) s.toPlace(),
    ];
    if (!mounted || controller != _controller) return;
    _dotPlaces = dots;

    await controller.addSource(
      _dotsSource,
      GeojsonSourceProperties(
        data: {
          'type': 'FeatureCollection',
          'features': [
            for (final (i, p) in dots.indexed)
              {
                'type': 'Feature',
                'id': i,
                'properties': {
                  'color': p.category.colorHex,
                  'sight': p.category == PlaceCategory.sight,
                },
                'geometry': {
                  'type': 'Point',
                  'coordinates': [p.longitude, p.latitude],
                },
              },
          ],
        },
      ),
    );

    // Dots in their category colour; sights a bit larger.
    await controller.addCircleLayer(
      _dotsSource,
      _dotLayer,
      const CircleLayerProperties(
        circleColor: ['get', 'color'],
        circleRadius: [
          'case',
          ['get', 'sight'],
          8,
          6,
        ],
        circleStrokeWidth: 2,
        circleStrokeColor: '#FFFFFF',
      ),
    );
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == _dotLayer) {
      final index = num.tryParse(id)?.toInt();
      if (index != null && index >= 0 && index < _dotPlaces.length) {
        _showPlace(_dotPlaces[index]);
      }
    }
  }

  void _retry() {
    _dotPlaces = const [];
    setState(() {
      _controller = null;
      _placeMarker = null; // belonged to the discarded native map
      _routeLine = null;
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

    // "Show on map" / "Route" from another tab (Favorites).
    ref.listen(mapFocusProvider, (_, request) {
      if (request == null) return;
      Future.microtask(() async {
        ref.read(mapFocusProvider.notifier).clear();
        await _showPlace(request.place, zoom: request.zoom);
        if (request.withRoute && mounted) _startRoute(request.place);
      });
    });

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
          Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchBar(onTap: _openSearch),
                  const SizedBox(height: 8),
                  _CategoryChips(onSelected: _openCategory),
                  if (!_offlineBannerDismissed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OfflineMapBanner(
                        onDismiss: () =>
                            setState(() => _offlineBannerDismissed = true),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_status == _MapStatus.ready)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ZoomButtons(
                  onZoomIn: () =>
                      _controller?.animateCamera(CameraUpdate.zoomIn()),
                  onZoomOut: () =>
                      _controller?.animateCamera(CameraUpdate.zoomOut()),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            // Above the floating tab bar (the shell extends the body under it).
            bottom: MediaQuery.paddingOf(context).bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_status == _MapStatus.ready)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 12),
                      child: _MapButtons(
                        locating: _locating,
                        onRecenter: _recenter,
                        onMyLocation: _goToMyLocation,
                      ),
                    ),
                  ),
                // Always visible, just above the sheet (ODbL).
                const _Attribution(),
                if (_route case final route?)
                  RoutePanel(
                    session: route,
                    onClose: _closeRoute,
                    onModeChanged: _changeRouteMode,
                    onChooseOrigin: _chooseRouteOrigin,
                    onUseMyLocation: _routeFromMyLocation,
                  )
                else if (_selectedPlace case final place?)
                  _PlaceCard(
                    place: place,
                    onClose: _clearPlace,
                    onRoute: () => _startRoute(place),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(
                  'Поиск в Аральске',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick categories under the search bar, in their map colours.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.onSelected});

  final ValueChanged<PlaceCategory> onSelected;

  static const _categories = [
    PlaceCategory.food,
    PlaceCategory.grocery,
    PlaceCategory.pharmacy,
    PlaceCategory.health,
    PlaceCategory.transport,
    PlaceCategory.lodging,
    PlaceCategory.fuel,
    PlaceCategory.finance,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _categories[i];
          return ActionChip(
            avatar: Icon(c.icon, size: 18, color: c.color),
            label: Text(c.label),
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 2,
            shadowColor: Colors.black26,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            onPressed: () => onSelected(c),
          );
        },
      ),
    );
  }
}

/// Bottom-right: back to Aral, and "where am I" (the main map button).
class _MapButtons extends StatelessWidget {
  const _MapButtons({
    required this.locating,
    required this.onRecenter,
    required this.onMyLocation,
  });

  final bool locating;
  final VoidCallback onRecenter;
  final VoidCallback onMyLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapRoundButton(
          icon: Icons.location_city,
          tooltip: 'Показать Аральск',
          onPressed: onRecenter,
          size: 44,
        ),
        const SizedBox(height: 12),
        MapRoundButton(
          icon: Icons.near_me,
          tooltip: 'Где я',
          onPressed: onMyLocation,
          size: 54,
          iconColor: Theme.of(context).colorScheme.primary,
          busy: locating,
        ),
      ],
    );
  }
}

/// Right edge, mid-height: zoom in / out.
class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      MapRoundButton(
        icon: Icons.add,
        tooltip: 'Приблизить',
        onPressed: onZoomIn,
      ),
      const SizedBox(height: 10),
      MapRoundButton(
        icon: Icons.remove,
        tooltip: 'Отдалить',
        onPressed: onZoomOut,
      ),
    ],
  );
}

/// Place page at the bottom: what it is, then actions in a row.
class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({
    required this.place,
    required this.onClose,
    required this.onRoute,
  });

  final Place place;
  final VoidCallback onClose;
  final VoidCallback onRoute;

  /// The Explore entry for this place, if it is one of the sights.
  Sight? get _sight =>
      sights.where((s) => s.hasLocation && s.title == place.name).firstOrNull;

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref.read(favoritesProvider.notifier).toggle(place);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Добавлено в избранное' : 'Удалено из избранного',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFavorite =
        ref.watch(favoritesProvider).value?.contains(place) ?? false;
    final sight = _sight;

    return MapSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryAvatar(place.category, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(place.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      place.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: place.category.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _CloseButton(onPressed: onClose),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SheetAction(
                icon: Icons.directions,
                label: 'Маршрут',
                primary: true,
                onTap: onRoute,
              ),
              SheetAction(
                icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
                label: isFavorite ? 'В избранном' : 'Сохранить',
                onTap: () => _toggleFavorite(context, ref),
              ),
              if (sight != null)
                SheetAction(
                  icon: Icons.auto_stories_outlined,
                  label: 'Подробнее',
                  onTap: () => context.go(AppRoutes.sight(sight.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small grey round "×" in the corner of a sheet.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Закрыть',
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.outline
          .withValues(alpha: 0.5),
      minimumSize: const Size.square(32),
      padding: EdgeInsets.zero,
    ),
    icon: const Icon(Icons.close, size: 18),
  );
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
          'Проверьте интернет. Чтобы карта работала без связи, '
          'скачайте её в разделе «Профиль».',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
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
