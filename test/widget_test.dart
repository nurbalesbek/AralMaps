import 'package:aralmap/app.dart';
import 'package:aralmap/features/map/presentation/widgets/map_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Stands in for the native map (platform views don't run in widget tests).
/// [loads] decides whether it reports "style loaded".
MapViewBuilder fakeMapView({required bool loads}) =>
    ({Key? key, required onMapCreated, required onStyleLoaded}) =>
        _FakeMap(key: key, onStyleLoaded: loads ? onStyleLoaded : null);

/// Reports "style loaded" once, like the real map does.
class _FakeMap extends StatefulWidget {
  const _FakeMap({super.key, this.onStyleLoaded});

  final VoidCallback? onStyleLoaded;

  @override
  State<_FakeMap> createState() => _FakeMapState();
}

class _FakeMapState extends State<_FakeMap> {
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

Widget appWith(MapViewBuilder builder) => ProviderScope(
  overrides: [mapViewBuilderProvider.overrideWithValue(builder)],
  child: const AralMapApp(),
);

void main() {
  testWidgets('Map tab shows the map, attribution and recenter button', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(fakeMapView(loads: true)));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
    expect(find.byTooltip('Показать Аральск'), findsOneWidget);
    expect(find.text('Загрузка карты…'), findsNothing);
  });

  testWidgets('Map shows an error with retry when the style never loads', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(fakeMapView(loads: false)));
    await tester.pump();
    expect(find.text('Загрузка карты…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Не удалось загрузить карту'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(find.text('Загрузка карты…'), findsOneWidget);
  });

  testWidgets('Switching tabs works', (tester) async {
    await tester.pumpWidget(appWith(fakeMapView(loads: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Избранное'));
    await tester.pumpAndSettle();
    expect(find.text('Пока пусто'), findsOneWidget);

    await tester.tap(find.text('Карта'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Показать Аральск'), findsOneWidget);
  });
}
