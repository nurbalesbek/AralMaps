# AralMap

Offline-first mobile map of Aral (Аральск), Kazakhstan. Flutter + MapLibre + OpenStreetMap.

> Status: **Phase 6 — offline map of Aral (one-time ~14 MB download), "where am I", offline place search, offline walking and driving routes.** No turn-by-turn navigation.

## Requirements

| Tool | Version used |
|---|---|
| Flutter | 3.50.1 (stable), Dart 3.14 |
| JDK | Temurin 21 (required by `maplibre_gl`) |
| Android SDK | Platform 36, Build-Tools 36 |

The project path must contain only Latin characters and no spaces (Gradle fails on Cyrillic paths on Windows).

## Run

```powershell
flutter pub get
flutter run            # on a connected Android phone or emulator
flutter test
flutter analyze
```

## Project structure

```
lib/
  main.dart                 entry point (ProviderScope)
  app.dart                  MaterialApp.router + theme
  core/
    router/                 GoRouter config and route paths
    theme/                  colors and ThemeData
  features/<feature>/
    data/                   repositories, data sources (added when needed)
    domain/                 models, business logic (added when needed)
    presentation/           screens and widgets
  shared/widgets/           widgets used by several features
```

Folders are created when the first file needs them, not upfront.

## Data and licensing

Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), available under the
Open Database License (ODbL). Attribution must stay visible in the app.

### Offline map

The app downloads the map once into MapLibre's offline database (style, tiles, fonts from
OpenFreeMap): Aral town at zoom 10–16 and the surroundings (Aral Sea, roads) at zoom 4–10,
about 14 MB. After that the map works without internet. Regions are defined in
`lib/features/offline/data/offline_map_service.dart`; status and delete are in the Profile tab.

### Routing data

`assets/data/aral_roads.json` (~94 KB) is the road network of Aral from OpenStreetMap: every
road and footpath as a graph with walk / car-forward / car-backward flags (one-way streets,
`access=no`, foot-only paths) and a road class for speeds. Routes are computed on the device
with A* by travel time (`lib/features/routing/domain/road_graph.dart`). To refresh:

```powershell
dart run tool/fetch_roads.dart
```

Times are estimates (walking 4.5 km/h; driving by road class, no traffic or lights).

### Search data

`assets/data/aral_places.json` holds the named places of Aral (streets, shops, schools, clinics…)
extracted from OpenStreetMap via the Overpass API. It is bundled so search works offline.
To refresh it after OSM edits:

```powershell
dart run tool/fetch_places.dart
```

Search only knows what is mapped in OSM; missing places should be added on openstreetmap.org.
The file is a derived ODbL database and keeps the attribution inside it.
