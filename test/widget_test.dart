import 'package:aralmap/app.dart';
import 'package:aralmap/features/location/data/location_service.dart';
import 'package:aralmap/features/location/domain/location_result.dart';
import 'package:aralmap/features/map/presentation/widgets/map_view.dart';
import 'package:aralmap/features/search/data/places_repository.dart';
import 'package:aralmap/features/search/domain/place.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Stands in for the native map (platform views don't run in widget tests).
class FakeMap {
  FakeMap({this.loads = true});

  final bool loads;

  /// The last value the screen passed for the blue dot.
  bool myLocationEnabled = false;

  Widget build({
    Key? key,
    required onMapCreated,
    required onStyleLoaded,
    required bool myLocationEnabled,
  }) {
    this.myLocationEnabled = myLocationEnabled;
    return _FakeMapWidget(
      key: key,
      onStyleLoaded: loads ? onStyleLoaded : null,
    );
  }
}

/// Reports "style loaded" once, like the real map does.
class _FakeMapWidget extends StatefulWidget {
  const _FakeMapWidget({super.key, this.onStyleLoaded});

  final VoidCallback? onStyleLoaded;

  @override
  State<_FakeMapWidget> createState() => _FakeMapWidgetState();
}

class _FakeMapWidgetState extends State<_FakeMapWidget> {
  @override
  void initState() {
    super.initState();
    final onStyleLoaded = widget.onStyleLoaded;
    if (onStyleLoaded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onStyleLoaded());
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class FakeLocationService implements LocationService {
  FakeLocationService({this.granted = false, required this.result});

  bool granted;
  final LocationResult result;
  int openedAppSettings = 0;
  int openedLocationSettings = 0;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<LocationResult> locate() async {
    if (result is LocationFound) granted = true;
    return result;
  }

  @override
  Future<void> openAppSettings() async => openedAppSettings++;

  @override
  Future<void> openLocationSettings() async => openedLocationSettings++;
}

const _inAral = LocationFound(
  latitude: 46.8,
  longitude: 61.67,
  accuracyMeters: 10,
);

const _pharmacy = Place(
  name: 'Europharma',
  category: PlaceCategory.pharmacy,
  latitude: 46.79,
  longitude: 61.66,
);
const _street = Place(
  name: 'Абая',
  category: PlaceCategory.street,
  latitude: 46.8,
  longitude: 61.67,
);

Widget appWith(FakeMap map, {LocationService? location}) => ProviderScope(
  overrides: [
    mapViewBuilderProvider.overrideWithValue(map.build),
    locationServiceProvider.overrideWithValue(
      location ?? FakeLocationService(result: _inAral),
    ),
    placesProvider.overrideWith((ref) async => [_pharmacy, _street]),
  ],
  child: const AralMapApp(),
);

void main() {
  testWidgets('Map tab shows the map, attribution and both buttons', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(FakeMap()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
    expect(find.byTooltip('Показать Аральск'), findsOneWidget);
    expect(find.byTooltip('Где я'), findsOneWidget);
    expect(find.text('Загрузка карты…'), findsNothing);
  });

  testWidgets('Map shows an error with retry when the style never loads', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(FakeMap(loads: false)));
    await tester.pump();
    expect(find.text('Загрузка карты…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Не удалось загрузить карту'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(find.text('Загрузка карты…'), findsOneWidget);
  });

  group('Where am I', () {
    testWidgets('no blue dot and no prompt until the button is tapped', (
      tester,
    ) async {
      final map = FakeMap();
      await tester.pumpWidget(appWith(map));
      await tester.pumpAndSettle();
      expect(map.myLocationEnabled, isFalse);
    });

    testWidgets('blue dot is shown at start if permission was granted', (
      tester,
    ) async {
      final map = FakeMap();
      await tester.pumpWidget(
        appWith(
          map,
          location: FakeLocationService(granted: true, result: _inAral),
        ),
      );
      await tester.pumpAndSettle();
      expect(map.myLocationEnabled, isTrue);
    });

    testWidgets('finding the location turns on the blue dot', (tester) async {
      final map = FakeMap();
      await tester.pumpWidget(appWith(map));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Где я'));
      await tester.pumpAndSettle();

      expect(map.myLocationEnabled, isTrue);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('GPS off: message with a button to the location settings', (
      tester,
    ) async {
      final location = FakeLocationService(
        result: const LocationFailed(LocationFailure.serviceDisabled),
      );
      await tester.pumpWidget(appWith(FakeMap(), location: location));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Где я'));
      await tester.pumpAndSettle();
      expect(find.text('Геолокация выключена на телефоне'), findsOneWidget);

      await tester.tap(find.text('Включить'));
      expect(location.openedLocationSettings, 1);
    });

    testWidgets('blocked permission: message with a button to app settings', (
      tester,
    ) async {
      final map = FakeMap();
      final location = FakeLocationService(
        result: const LocationFailed(LocationFailure.deniedForever),
      );
      await tester.pumpWidget(appWith(map, location: location));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Где я'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Разрешите его в настройках'), findsOneWidget);
      expect(map.myLocationEnabled, isFalse);

      await tester.tap(find.text('Настройки'));
      expect(location.openedAppSettings, 1);
    });
  });

  group('Search', () {
    testWidgets('pick a result: back on the map with its card', (tester) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Поиск в Аральске'));
      await tester.pumpAndSettle();
      expect(find.text('Что найти'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'аптека');
      await tester.pumpAndSettle();
      expect(find.text('Europharma'), findsOneWidget);
      expect(find.text('Абая'), findsNothing);

      await tester.tap(find.text('Europharma'));
      await tester.pumpAndSettle();

      // Back on the map, with the place card and the attribution visible.
      expect(find.text('Поиск в Аральске'), findsOneWidget);
      expect(find.text('Europharma'), findsOneWidget);
      expect(find.text('Аптека'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);

      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.text('Europharma'), findsNothing);
    });

    testWidgets('category chip fills the query', (tester) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Поиск в Аральске'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, 'Аптека'));
      await tester.pumpAndSettle();
      expect(find.text('Europharma'), findsOneWidget);
    });

    testWidgets('no results shows a helpful message', (tester) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Поиск в Аральске'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
    });

    testWidgets('bundled OSM data loads and parses', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final places = await tester.runAsync(
        () => container.read(placesProvider.future),
      );
      expect(places, isNotNull);
      expect(places!.length, greaterThan(100));
      expect(
        places.where((p) => p.category == PlaceCategory.street),
        isNotEmpty,
      );
    });
  });

  testWidgets('Switching tabs works', (tester) async {
    await tester.pumpWidget(appWith(FakeMap()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Избранное'));
    await tester.pumpAndSettle();
    expect(find.text('Пока пусто'), findsOneWidget);

    await tester.tap(find.text('Карта'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Где я'), findsOneWidget);
  });
}
