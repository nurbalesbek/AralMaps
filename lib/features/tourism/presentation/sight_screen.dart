import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
import '../../map/presentation/map_focus.dart';
import '../data/sights.dart';
import '../domain/sight.dart';
import 'explore_screen.dart';
import 'sight_visuals.dart';

class SightScreen extends ConsumerWidget {
  const SightScreen({super.key, required this.sightId});

  final String sightId;

  /// Zoom for sights outside town: the offline map there has overview
  /// detail only, so street-level zoom would show nothing more.
  static const _nearbyZoom = 11.0;

  void _showOnMap(
    BuildContext context,
    WidgetRef ref,
    Sight sight,
    bool route,
  ) {
    ref
        .read(mapFocusProvider.notifier)
        .request(
          sight.toPlace(),
          withRoute: route,
          zoom: sight.area == SightArea.nearby ? _nearbyZoom : null,
        );
    context.go(AppRoutes.map);
  }

  Future<void> _openSource(BuildContext context, SightSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(
      Uri.parse(source.url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sight = sights.where((s) => s.id == sightId).firstOrNull;
    if (sight == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Место не найдено')),
      );
    }
    final theme = Theme.of(context);
    final distance = sightDistanceText(sight);

    return Scaffold(
      appBar: AppBar(title: Text(sight.area.label)),
      body: ListView(
        // + bottom inset: content stays above the floating tab bar.
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 210,
              child: SightCover(sight: sight, iconSize: 72),
            ),
          ),
          PhotoCreditLine(sightId: sight.id),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: sightColor(sight),
                foregroundColor: Colors.white,
                child: Icon(sight.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(sight.title, style: theme.textTheme.headlineSmall),
              ),
            ],
          ),
          if (distance != null) ...[
            const SizedBox(height: 8),
            Text(distance, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          for (final paragraph in sight.description)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(paragraph, style: theme.textTheme.bodyLarge),
            ),
          if (sight.practical case final practical?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(practical, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (sight.hasLocation)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _showOnMap(context, ref, sight, false),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Показать на карте'),
                ),
                // Routes only cover the town's roads.
                if (sight.area == SightArea.town)
                  FilledButton.tonalIcon(
                    onPressed: () => _showOnMap(context, ref, sight, true),
                    icon: const Icon(Icons.directions),
                    label: const Text('Маршрут'),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          Text('Источники', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final source in sight.sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.link, size: 20),
              title: Text(source.title),
              subtitle: Text(
                Uri.parse(source.url).host,
                style: theme.textTheme.bodySmall,
              ),
              onTap: () => _openSource(context, source),
            ),
        ],
      ),
    );
  }
}
