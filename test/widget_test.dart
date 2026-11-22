import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:aralmap/app.dart';
import 'package:aralmap/features/account/data/auth_service.dart';
import 'package:aralmap/features/favorites/data/favorites_repository.dart';
import 'package:aralmap/features/favorites/data/remote_favorites.dart';
import 'package:aralmap/features/offline/data/offline_map_service.dart';
import 'package:aralmap/features/offline/presentation/offline_map_controller.dart';
import 'package:flutter/services.dart';
import 'package:aralmap/features/location/data/location_service.dart';
import 'package:aralmap/features/location/domain/location_result.dart';
import 'package:aralmap/features/map/presentation/widgets/map_view.dart';
import 'package:aralmap/features/routing/data/road_graph_repository.dart';
import 'package:aralmap/features/routing/domain/road_graph.dart';
import 'package:aralmap/features/search/data/places_repository.dart';
import 'package:aralmap/features/search/domain/place.dart';
import 'package:aralmap/features/tourism/data/photo_credits.dart';
import 'package:aralmap/features/tourism/data/sights.dart';
import 'package:aralmap/features/tourism/domain/sight.dart';
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

/// One street from "Абая" / the test location (46.8, 61.67) to the
/// pharmacy (46.79, 61.66).
final _testRoads = RoadGraph.fromEncoded(
  vertices: [4680000, 6167000, -1000, -1000], // delta-encoded
  edges: [0, 1, 1 | 2 | 4, 6], // walk + car both ways, residential
);

String _expectedSummary(TravelMode mode) {
  final r = _testRoads.route(
    (lat: 46.8, lon: 61.67),
    (lat: 46.79, lon: 61.66),
    mode,
  ) as RouteFound;
  return '${formatDuration(r.durationSeconds)} · '
      '${formatDistance(r.distanceMeters)}';
}

class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository([
    List<Place> initial = const [],
    this.meta = const SyncMeta(),
  ]) : saved = [...initial];

  List<Place> saved;
  SyncMeta meta;

  @override
  Future<List<Place>> load() async => [...saved];

  @override
  Future<void> save(List<Place> places) async => saved = [...places];

  @override
  Future<SyncMeta> loadMeta() async => meta;

  @override
  Future<void> saveMeta(SyncMeta m) async => meta = m;
}

class FakeAuthService implements AuthService {
  // A private field can't be a named initializing formal.
  // ignore: prefer_initializing_formals
  FakeAuthService({AppUser? user, this.validCode = '123456'}) : _user = user;

  AppUser? _user;
  final String validCode;
  final _changes = StreamController<AppUser?>.broadcast();
  final sentTo = <String>[];
  bool deleted = false;

  @override
  bool get isAvailable => true;
  @override
  AppUser? get currentUser => _user;
  @override
  Stream<AppUser?> get userChanges => _changes.stream;

  void _set(AppUser? u) {
    _user = u;
    _changes.add(u);
  }

  @override
  Future<void> sendCode(String email) async => sentTo.add(email);

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code != validCode) {
      throw const AuthFailure('Код неверный или устарел. Запросите новый.');
    }
    _set(AppUser(id: 'user-1', email: email));
  }

  @override
  Future<void> signOut() async => _set(null);

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    _set(null);
  }
}

class FakeRemoteFavorites implements RemoteFavorites {
  FakeRemoteFavorites([this.stored]);

  List<Place>? stored;
  bool offline = false;
  int pushes = 0;

  @override
  Future<List<Place>?> fetch(String userId) async {
    if (offline) throw const SocketException('offline');
    return stored == null ? null : [...stored!];
  }

  @override
  Future<void> push(String userId, List<Place> places) async {
    if (offline) throw const SocketException('offline');
    pushes++;
    stored = [...places];
  }
}

const _alice = AppUser(id: 'user-1', email: 'alice@mail.kz');

/// Credits like the real ones, without the image files (tests don't draw
/// asset images).
final Map<String, SightPhoto> _testPhotos = {
  'zhalanash': (
    asset: 'assets/photos/zhalanash.jpg',
    credit: const PhotoCredit(
      author: 'Zhanat Kulenov',
      license: 'CC BY-SA 3.0 igo',
      source: 'https://commons.wikimedia.org/wiki/File:x.jpg',
      year: '2006',
    ),
  ),
};

class FakeOfflineMapService implements OfflineMapService {
  FakeOfflineMapService({this.stored, this.fail = false});

  int? stored;
  final bool fail;

  /// Lets a test hold the download "in progress" until it completes this.
  Completer<void>? gate;

  @override
  Future<int?> storedBytes() async => stored;

  @override
  Future<void> download({
    required void Function(OfflineProgress) onProgress,
  }) async {
    onProgress((completed: 1, required: 2, bytes: 3 * 1024 * 1024));
    await gate?.future;
    if (fail) {
      throw PlatformException(code: 'TILE_COUNT_LIMIT_EXCEEDED');
    }
    stored = 12 * 1024 * 1024;
  }

  @override
  Future<void> delete() async => stored = null;
}

Widget appWith(
  FakeMap map, {
  LocationService? location,
  OfflineMapService? offline,
  FavoritesRepository? favorites,
  AuthService? auth,
  RemoteFavorites? remote,
}) => ProviderScope(
  overrides: [
    mapViewBuilderProvider.overrideWithValue(map.build),
    locationServiceProvider.overrideWithValue(
      location ?? FakeLocationService(result: _inAral),
    ),
    placesProvider.overrideWith((ref) async => [_pharmacy, _street]),
    // Default: already downloaded, so the prompt does not get in the way.
    offlineMapServiceProvider.overrideWithValue(
      offline ?? FakeOfflineMapService(stored: 1024 * 1024),
    ),
    roadGraphProvider.overrideWith((ref) async => _testRoads),
    favoritesRepositoryProvider.overrideWithValue(
      favorites ?? FakeFavoritesRepository(),
    ),
    // Default: a build without Supabase keys (accounts unavailable).
    authServiceProvider.overrideWithValue(
      auth ?? const UnavailableAuthService(),
    ),
    remoteFavoritesProvider.overrideWithValue(remote),
    // Real credits.json is checked by its own test below; widget tests get
    // the data synchronously.
    sightPhotosProvider.overrideWith((ref) async => _testPhotos),
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
      // In the place card (the category chip row also says "Аптека").
      expect(find.widgetWithText(Card, 'Аптека'), findsOneWidget);
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

  group('Offline map', () {
    testWidgets('no prompt when the map is already downloaded', (tester) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      expect(find.text('Карта без интернета'), findsNothing);
    });

    testWidgets('download from the prompt: progress, then prompt disappears', (
      tester,
    ) async {
      final offline = FakeOfflineMapService()..gate = Completer<void>();
      await tester.pumpWidget(appWith(FakeMap(), offline: offline));
      await tester.pumpAndSettle();
      expect(find.text('Карта без интернета'), findsOneWidget);

      await tester.tap(find.text('Скачать'));
      await tester.pump();
      expect(find.text('Скачивание карты… 50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      offline.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Скачивание карты'), findsNothing);
      expect(find.text('Карта без интернета'), findsNothing);

      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Скачана · 12 МБ'), findsOneWidget);
    });

    testWidgets('"Later" hides the prompt', (tester) async {
      await tester.pumpWidget(
        appWith(FakeMap(), offline: FakeOfflineMapService()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Позже'));
      await tester.pumpAndSettle();
      expect(find.text('Карта без интернета'), findsNothing);
    });

    testWidgets('failed download offers a retry', (tester) async {
      await tester.pumpWidget(
        appWith(FakeMap(), offline: FakeOfflineMapService(fail: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Скачать'));
      await tester.pumpAndSettle();
      expect(find.text('Карта не скачана'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('delete from Profile asks first, then removes the map', (
      tester,
    ) async {
      final offline = FakeOfflineMapService(stored: 5 * 1024 * 1024);
      await tester.pumpWidget(appWith(FakeMap(), offline: offline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Скачана · 5.0 МБ'), findsOneWidget);

      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить офлайн-карту?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pumpAndSettle();
      expect(offline.stored, isNull);
      expect(find.textContaining('Не скачана'), findsOneWidget);
    });
  });

  group('Route', () {
    Future<void> openPharmacy(WidgetTester tester) async {
      await tester.tap(find.text('Поиск в Аральске'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'europharma');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Europharma'));
      await tester.pumpAndSettle();
    }

    testWidgets('from my location: walk, then drive, then close', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      await openPharmacy(tester);

      await tester.tap(find.text('Маршрут'));
      await tester.pumpAndSettle();
      expect(find.text('Маршрут: Europharma'), findsOneWidget);
      expect(find.text('Моё местоположение'), findsOneWidget);
      expect(find.text(_expectedSummary(TravelMode.walk)), findsOneWidget);

      await tester.tap(find.text('На машине'));
      await tester.pumpAndSettle();
      expect(find.text(_expectedSummary(TravelMode.drive)), findsOneWidget);
      expect(find.textContaining('без учёта пробок'), findsOneWidget);

      await tester.tap(find.byTooltip('Закрыть маршрут'));
      await tester.pumpAndSettle();
      expect(find.text('Маршрут: Europharma'), findsNothing);
      expect(find.text('Europharma'), findsOneWidget); // place card again
      // Attribution never disappears.
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
    });

    testWidgets('far from Aral: explains, then routes from a chosen place', (
      tester,
    ) async {
      final inAlmaty = FakeLocationService(
        result: const LocationFound(
          latitude: 43.24,
          longitude: 76.89,
          accuracyMeters: 10,
        ),
      );
      await tester.pumpWidget(appWith(FakeMap(), location: inAlmaty));
      await tester.pumpAndSettle();
      await openPharmacy(tester);

      await tester.tap(find.text('Маршрут'));
      await tester.pumpAndSettle();
      expect(find.textContaining('км от Аральска'), findsOneWidget);

      await tester.tap(find.text('Выбрать откуда'));
      await tester.pumpAndSettle();
      expect(find.text('Откуда идти?'), findsOneWidget); // search hint

      await tester.enterText(find.byType(TextField), 'абая');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Абая'));
      await tester.pumpAndSettle();

      expect(find.text('Маршрут: Europharma'), findsOneWidget);
      expect(find.text(_expectedSummary(TravelMode.walk)), findsOneWidget);
      expect(find.byTooltip('От моего местоположения'), findsOneWidget);
    });

    testWidgets('location unavailable: offers to choose the origin', (
      tester,
    ) async {
      final noGps = FakeLocationService(
        result: const LocationFailed(LocationFailure.serviceDisabled),
      );
      await tester.pumpWidget(appWith(FakeMap(), location: noGps));
      await tester.pumpAndSettle();
      await openPharmacy(tester);

      await tester.tap(find.text('Маршрут'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Не удалось определить, где вы'),
        findsOneWidget,
      );
      expect(find.text('Выбрать откуда'), findsOneWidget);
    });
  });

  group('Favorites', () {
    Future<void> openPharmacy(WidgetTester tester) async {
      await tester.tap(find.text('Поиск в Аральске'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'europharma');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Europharma'));
      await tester.pumpAndSettle();
    }

    Future<void> goToFavorites(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(NavigationDestination, 'Избранное'));
      await tester.pumpAndSettle();
    }

    testWidgets('save from the place card; it is stored and listed', (
      tester,
    ) async {
      final repo = FakeFavoritesRepository();
      await tester.pumpWidget(appWith(FakeMap(), favorites: repo));
      await tester.pumpAndSettle();
      await openPharmacy(tester);

      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('В избранном'), findsOneWidget);
      expect(find.text('Добавлено в избранное'), findsOneWidget);
      expect(repo.saved, [_pharmacy]);

      await goToFavorites(tester);
      expect(find.text('Europharma'), findsOneWidget);
      expect(find.text('Пока пусто'), findsNothing);
    });

    testWidgets('saved places load at start; tap shows it on the map', (
      tester,
    ) async {
      await tester.pumpWidget(
        appWith(FakeMap(), favorites: FakeFavoritesRepository([_pharmacy])),
      );
      await tester.pumpAndSettle();
      await goToFavorites(tester);

      await tester.tap(find.text('Europharma'));
      await tester.pumpAndSettle();
      // On the map tab, with the place card.
      expect(find.text('Поиск в Аральске'), findsOneWidget);
      expect(find.text('В избранном'), findsOneWidget);
    });

    testWidgets('route button in Favorites opens the route on the map', (
      tester,
    ) async {
      await tester.pumpWidget(
        appWith(FakeMap(), favorites: FakeFavoritesRepository([_pharmacy])),
      );
      await tester.pumpAndSettle();
      await goToFavorites(tester);

      await tester.tap(find.byTooltip('Маршрут к «Europharma»'));
      await tester.pumpAndSettle();
      expect(find.text('Маршрут: Europharma'), findsOneWidget);
      expect(find.text(_expectedSummary(TravelMode.walk)), findsOneWidget);
    });

    testWidgets('swipe removes, "Вернуть" restores', (tester) async {
      final repo = FakeFavoritesRepository([_pharmacy, _street]);
      await tester.pumpWidget(appWith(FakeMap(), favorites: repo));
      await tester.pumpAndSettle();
      await goToFavorites(tester);

      await tester.drag(find.text('Europharma'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Europharma'), findsNothing);
      expect(repo.saved, [_street]);

      await tester.tap(find.text('Вернуть'));
      await tester.pumpAndSettle();
      expect(find.text('Europharma'), findsOneWidget);
      expect(repo.saved, [_pharmacy, _street]); // back in its old position
    });

    testWidgets('unsave from the card', (tester) async {
      final repo = FakeFavoritesRepository([_pharmacy]);
      await tester.pumpWidget(appWith(FakeMap(), favorites: repo));
      await tester.pumpAndSettle();
      await openPharmacy(tester);

      await tester.tap(find.text('В избранном'));
      await tester.pumpAndSettle();
      expect(find.text('Сохранить'), findsOneWidget);
      expect(repo.saved, isEmpty);
    });
  });

  group('Explore', () {
    Future<void> openExplore(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(NavigationDestination, 'Обзор'));
      await tester.pumpAndSettle();
    }

    /// The vertical list (the fact tiles scroll sideways inside it).
    Finder exploreList() => find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> openSight(WidgetTester tester, String title) async {
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: exploreList(),
      );
      // Fully into view, or the bottom navigation bar catches the tap.
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    testWidgets('lists town and nearby sights; far ones show distance', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      await openExplore(tester);

      expect(find.text('Аральск'), findsOneWidget); // header
      expect(find.text('1905'), findsOneWidget); // fact tile
      await tester.scrollUntilVisible(
        find.text('Вокзал и мозаика о рыбе для Поволжья'),
        200,
        scrollable: exploreList(),
      );
      await tester.scrollUntilVisible(
        find.text('Кокаральская плотина'),
        200,
        scrollable: exploreList(),
      );
      expect(find.textContaining('км'), findsWidgets); // distance badge
    });

    testWidgets('town sight: description, sources, route opens on the map', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      await openExplore(tester);
      await openSight(tester, 'Вокзал и мозаика о рыбе для Поволжья');

      await tester.scrollUntilVisible(
        find.textContaining('построен в 1905 году'),
        200,
      );
      await tester.scrollUntilVisible(find.text('Источники'), 200);
      expect(find.text('Wikipedia: Aral, Kazakhstan'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Маршрут'), -200);
      await tester.tap(find.text('Маршрут'));
      await tester.pumpAndSettle();
      expect(
        find.text('Маршрут: Вокзал и мозаика о рыбе для Поволжья'),
        findsOneWidget,
      );
    });

    testWidgets('sight without a known position offers no map buttons', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      await openExplore(tester);
      await openSight(tester, 'Краеведческий музей');

      await tester.scrollUntilVisible(
        find.textContaining('не отмечена в OpenStreetMap'),
        200,
      );
      expect(find.text('Показать на карте'), findsNothing);
      expect(find.text('Маршрут'), findsNothing);
      expect(
        find.textContaining('не отмечена в OpenStreetMap'),
        findsOneWidget,
      );
    });

    testWidgets('nearby sight: map yes, route no (roads cover only town)', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      await openExplore(tester);

      await openSight(tester, 'Жаланаш — бывшее «кладбище кораблей»');
      // Photo credit (2006 — the ships were mostly scrapped by 2017).
      expect(find.textContaining('Zhanat Kulenov'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('разрезаны на металлолом'),
        200,
      );
      await tester.scrollUntilVisible(find.text('Показать на карте'), 200);
      await tester.ensureVisible(find.text('Показать на карте'));
      await tester.pumpAndSettle();
      expect(find.text('Маршрут'), findsNothing);

      await tester.tap(find.text('Показать на карте'));
      await tester.pumpAndSettle();
      expect(find.text('Поиск в Аральске'), findsOneWidget); // on the map
      expect(find.textContaining('Жаланаш'), findsOneWidget); // place card
    });
  });

  test('bundled photo credits: every photo has author, license, source', () {
    final json = jsonDecode(
      File('assets/photos/credits.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(json, isNotEmpty);
    for (final MapEntry(:key, :value) in json.entries) {
      final c = PhotoCredit.fromJson(value as Map<String, dynamic>);
      expect(c.author, isNotEmpty, reason: key);
      expect(c.license, isNotEmpty, reason: key);
      expect(
        c.source,
        startsWith('https://commons.wikimedia.org/'),
        reason: key,
      );
      expect(File('assets/photos/$key.jpg').existsSync(), isTrue, reason: key);
      expect(sights.any((s) => s.id == key), isTrue, reason: '$key: no sight');
    }
    // The satellite image needs its Copernicus credit line.
    final kokaral = PhotoCredit.fromJson(
      json['kokaral-dam'] as Map<String, dynamic>,
    );
    expect(kokaral.line, contains('Copernicus'));
  });

  test('every sight has sources, and map positions are near Aral', () {
    for (final s in sights) {
      expect(s.sources, isNotEmpty, reason: s.id);
      if (s.hasLocation) {
        final km =
            distanceMeters(
              (lat: 46.8, lon: 61.667),
              (lat: s.latitude!, lon: s.longitude!),
            ) /
            1000;
        expect(km, lessThan(s.area == SightArea.town ? 5 : 150), reason: s.id);
      }
    }
    expect(sights.map((s) => s.id).toSet().length, sights.length);
  });

  group('Account', () {
    Future<void> openProfile(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(NavigationDestination, 'Профиль'));
      await tester.pumpAndSettle();
    }

    Future<void> openFavorites(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(NavigationDestination, 'Избранное'));
      await tester.pumpAndSettle();
    }

    testWidgets('build without keys: accounts shown as unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(FakeMap()));
      await tester.pumpAndSettle();
      await openProfile(tester);
      expect(find.text('Аккаунты недоступны в этой версии'), findsOneWidget);
    });

    testWidgets('sign in with an emailed code', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        appWith(FakeMap(), auth: auth, remote: FakeRemoteFavorites()),
      );
      await tester.pumpAndSettle();
      await openProfile(tester);

      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('Получить код'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Введите адрес почты'), findsOneWidget);
      expect(auth.sentTo, isEmpty);

      await tester.enterText(find.byType(TextField), 'alice@mail.kz');
      await tester.tap(find.text('Получить код'));
      await tester.pumpAndSettle();
      expect(auth.sentTo, ['alice@mail.kz']);
      expect(
        find.textContaining('отправили код на alice@mail.kz'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Код неверный'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      // Back on Profile, signed in and synced.
      expect(find.text('alice@mail.kz'), findsOneWidget);
      expect(find.text('Избранное сохранено в аккаунте'), findsOneWidget);
      // Let the resend countdown timer finish.
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('first sign-in merges phone and account favorites', (
      tester,
    ) async {
      final local = FakeFavoritesRepository([_pharmacy]);
      final remote = FakeRemoteFavorites([_street]);
      await tester.pumpWidget(
        appWith(
          FakeMap(),
          favorites: local,
          auth: FakeAuthService(user: _alice),
          remote: remote,
        ),
      );
      await tester.pumpAndSettle();
      await openFavorites(tester);

      expect(find.text('Europharma'), findsOneWidget);
      expect(find.text('Абая'), findsOneWidget);
      expect(remote.stored, [_pharmacy, _street]);
      expect(local.saved, [_pharmacy, _street]);
      expect(local.meta.userId, 'user-1');
    });

    testWidgets('later start takes the account version (other phone)', (
      tester,
    ) async {
      final local = FakeFavoritesRepository([
        _pharmacy,
      ], const SyncMeta(userId: 'user-1'));
      final remote = FakeRemoteFavorites([_street]); // changed elsewhere
      await tester.pumpWidget(
        appWith(
          FakeMap(),
          favorites: local,
          auth: FakeAuthService(user: _alice),
          remote: remote,
        ),
      );
      await tester.pumpAndSettle();
      await openFavorites(tester);

      expect(find.text('Абая'), findsOneWidget);
      expect(find.text('Europharma'), findsNothing);
    });

    testWidgets('offline: changes stay on the phone and are sent later', (
      tester,
    ) async {
      final local = FakeFavoritesRepository(
        const [],
        const SyncMeta(userId: 'user-1'),
      );
      final remote = FakeRemoteFavorites([])..offline = true;
      await tester.pumpWidget(
        appWith(
          FakeMap(),
          favorites: local,
          auth: FakeAuthService(user: _alice),
          remote: remote,
        ),
      );
      await tester.pumpAndSettle();

      // Save a place while offline.
      await tester.tap(find.text('Поиск в Аральске'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'europharma');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Europharma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(local.saved, [_pharmacy]);
      expect(local.meta.dirty, isTrue);
      expect(remote.stored, isEmpty);

      await openProfile(tester);
      expect(find.textContaining('изменения отправятся позже'), findsOneWidget);

      // Internet is back: retry sends the phone's version.
      remote.offline = false;
      await tester.tap(find.byTooltip('Повторить синхронизацию'));
      await tester.pumpAndSettle();
      expect(remote.stored, [_pharmacy]);
      expect(local.meta.dirty, isFalse);
      expect(find.text('Избранное сохранено в аккаунте'), findsOneWidget);
    });

    testWidgets('a failed download does not mark the phone as newer', (
      tester,
    ) async {
      final local = FakeFavoritesRepository([
        _pharmacy,
      ], const SyncMeta(userId: 'user-1'));
      final remote = FakeRemoteFavorites([_street])..offline = true;
      await tester.pumpWidget(
        appWith(
          FakeMap(),
          favorites: local,
          auth: FakeAuthService(user: _alice),
          remote: remote,
        ),
      );
      await tester.pumpAndSettle();
      expect(local.meta.dirty, isFalse);
      expect(remote.stored, [_street]); // untouched
    });

    testWidgets('sign out clears favorites from the phone only', (
      tester,
    ) async {
      final local = FakeFavoritesRepository([
        _pharmacy,
      ], const SyncMeta(userId: 'user-1'));
      final remote = FakeRemoteFavorites([_pharmacy]);
      await tester.pumpWidget(
        appWith(
          FakeMap(),
          favorites: local,
          auth: FakeAuthService(user: _alice),
          remote: remote,
        ),
      );
      await tester.pumpAndSettle();
      await openProfile(tester);

      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Выйти'));
      await tester.pumpAndSettle();

      expect(find.text('Вы не вошли'), findsOneWidget);
      expect(local.saved, isEmpty);
      expect(remote.stored, [_pharmacy]); // still in the account
    });

    testWidgets('delete account asks first, then signs out', (tester) async {
      final auth = FakeAuthService(user: _alice);
      await tester.pumpWidget(
        appWith(
          FakeMap(),
          favorites: FakeFavoritesRepository([
            _pharmacy,
          ], const SyncMeta(userId: 'user-1')),
          auth: auth,
          remote: FakeRemoteFavorites([_pharmacy]),
        ),
      );
      await tester.pumpAndSettle();
      await openProfile(tester);

      await tester.tap(find.text('Удалить аккаунт'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить аккаунт?'), findsOneWidget);
      await tester.tap(find.text('Удалить навсегда'));
      await tester.pumpAndSettle();

      expect(auth.deleted, isTrue);
      expect(find.text('Вы не вошли'), findsOneWidget);
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
