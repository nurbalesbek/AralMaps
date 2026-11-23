import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_routes.dart';
import '../../map/domain/map_config.dart';
import '../../routing/domain/road_graph.dart';
import '../data/sights.dart';
import '../domain/sight.dart';
import 'sight_visuals.dart';

/// Facts shown as coloured tiles. Each one is stated in the sources of the
/// sights it belongs to (see sights.dart); ranges where sources differ.
const _facts = [
  ('1905', 'открыта станция «Аральское Море»', Color(0xFF287E72)),
  (
    '14 вагонов',
    'рыбы отправили голодающему Поволжью в 1921',
    Color(0xFF8E44AD),
  ),
  ('≈100 км', 'так далеко от города отступало море', Color(0xFFB7791F)),
  ('2005', 'достроена Кокаральская плотина', Color(0xFF1F6F9F)),
  ('12–20 км', 'до воды сейчас (оценки 2015–2018)', Color(0xFFC0392B)),
];

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroSight = sights.firstWhere(
      (s) => s.id == 'harbour-fishermen-museum',
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            title: const Text('Обзор'),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  SightCover(sight: heroSight),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Color(0x00000000),
                          Color(0xCC000000),
                        ],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Аральск',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Бывший порт Аральского моря',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: PhotoCreditLine(sightId: heroSight.id),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _FactTiles()),
          const SliverToBoxAdapter(child: _HistoryEntry()),
          for (final area in SightArea.values) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(area.label, style: theme.textTheme.titleLarge),
              ),
            ),
            SliverList.separated(
              itemCount: sights.where((s) => s.area == area).length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SightCard(
                  sight: sights.where((s) => s.area == area).elementAt(i),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              // + bottom inset: stays above the floating tab bar.
              padding: EdgeInsets.fromLTRB(
                16,
                24,
                16,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Text(
                'Описания составлены по открытым источникам, ссылки — на '
                'странице каждого места. Фото — Wikimedia Commons, авторы '
                'указаны под снимками. Часы работы и состояние мест меняются: '
                'уточняйте на месте.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactTiles extends StatelessWidget {
  const _FactTiles();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // No fixed height: the row grows with the text, so large system font
    // sizes don't cut the facts off.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (value, text, color)) in _facts.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Big entry card to the town's story.
class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoutes.history),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F6F9F), Color(0xFF287E72)],
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.auto_stories, color: Colors.white, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'История Аральска',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'От «Шести колодцев» до моря, которое ушло и '
                        'начало возвращаться — 7 глав',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SightCard extends StatelessWidget {
  const _SightCard({required this.sight});

  final Sight sight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = sightDistanceText(sight);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.sight(sight.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SightCover(sight: sight),
                  if (distance != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _Badge(
                        icon: Icons.near_me_outlined,
                        text: distance.replaceFirst(
                          ' от Аральска по прямой',
                          '',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    margin: const EdgeInsets.only(right: 10, top: 2),
                    decoration: BoxDecoration(
                      color: sightColor(sight),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sight.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(sight.summary, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}

/// "≈ 103 км от Аральска по прямой" for sights outside the town.
String? sightDistanceText(Sight sight) {
  if (sight.area != SightArea.nearby || !sight.hasLocation) return null;
  final meters = distanceMeters(
    (lat: MapConfig.aralCenter.latitude, lon: MapConfig.aralCenter.longitude),
    (lat: sight.latitude!, lon: sight.longitude!),
  );
  return '≈ ${(meters / 1000).round()} км от Аральска по прямой';
}
