import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_routes.dart';
import '../../map/domain/map_config.dart';
import '../../routing/domain/road_graph.dart';
import '../data/sights.dart';
import '../domain/sight.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Обзор')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final area in SightArea.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                area.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            for (final sight in sights.where((s) => s.area == area))
              _SightTile(sight: sight),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Text(
              'Описания составлены по открытым источникам, ссылки — на '
              'странице каждого места. Часы работы и состояние мест меняются: '
              'уточняйте на месте.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SightTile extends StatelessWidget {
  const _SightTile({required this.sight});

  final Sight sight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = sightDistanceText(sight);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        foregroundColor: theme.colorScheme.primary,
        child: Icon(sight.icon, size: 20),
      ),
      title: Text(sight.title),
      subtitle: Text(
        distance == null ? sight.summary : '${sight.summary}\n$distance',
      ),
      isThreeLine: distance != null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(AppRoutes.sight(sight.id)),
    );
  }
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
