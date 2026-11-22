# AralMap

Offline-first mobile map of Aral (Аральск), Kazakhstan. Flutter + MapLibre + OpenStreetMap.

> Status: **Phase 4 — online map of Aral, "where am I", offline place search.** Routing and offline map tiles are not implemented yet.

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

### Search data

`assets/data/aral_places.json` holds the named places of Aral (streets, shops, schools, clinics…)
extracted from OpenStreetMap via the Overpass API. It is bundled so search works offline.
To refresh it after OSM edits:

```powershell
dart run tool/fetch_places.dart
```

Search only knows what is mapped in OSM; missing places should be added on openstreetmap.org.
The file is a derived ODbL database and keeps the attribution inside it.
