import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/map_controls.dart';
import '../domain/road_graph.dart';
import 'route_session.dart';

/// Bottom panel while a route is shown: origin, mode, result or problem.
class RoutePanel extends StatelessWidget {
  const RoutePanel({
    super.key,
    required this.session,
    required this.onClose,
    required this.onModeChanged,
    required this.onChooseOrigin,
    required this.onUseMyLocation,
  });

  final RouteSession session;
  final VoidCallback onClose;
  final ValueChanged<TravelMode> onModeChanged;
  final VoidCallback onChooseOrigin;
  final VoidCallback onUseMyLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MapSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.directions, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Маршрут: ${session.destination.name}',
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Закрыть маршрут',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.outline.withValues(
                    alpha: 0.5,
                  ),
                  minimumSize: const Size.square(32),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _OriginRow(
            origin: session.origin,
            onChoose: onChooseOrigin,
            onUseMyLocation: onUseMyLocation,
          ),
          const SizedBox(height: 10),
          SegmentedButton<TravelMode>(
            segments: const [
              ButtonSegment(
                value: TravelMode.walk,
                icon: Icon(Icons.directions_walk),
                label: Text('Пешком'),
              ),
              ButtonSegment(
                value: TravelMode.drive,
                icon: Icon(Icons.directions_car),
                label: Text('На машине'),
              ),
            ],
            selected: {session.mode},
            showSelectedIcon: false,
            onSelectionChanged: session.computing
                ? null
                : (s) => onModeChanged(s.first),
          ),
          const SizedBox(height: 14),
          _Outcome(session: session, onChooseOrigin: onChooseOrigin),
        ],
      ),
    );
  }
}

class _OriginRow extends StatelessWidget {
  const _OriginRow({
    required this.origin,
    required this.onChoose,
    required this.onUseMyLocation,
  });

  final RouteOrigin origin;
  final VoidCallback onChoose;
  final VoidCallback onUseMyLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label) = switch (origin) {
      FromMyLocation() => (Icons.my_location, 'Моё местоположение'),
      FromPlace(:final place) => (place.category.icon, place.name),
    };
    return Row(
      children: [
        Text('Откуда: ', style: theme.textTheme.bodySmall),
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (origin is FromPlace)
          IconButton(
            tooltip: 'От моего местоположения',
            icon: const Icon(Icons.my_location, size: 20),
            onPressed: onUseMyLocation,
          ),
        TextButton(onPressed: onChoose, child: const Text('Изменить')),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.session, required this.onChooseOrigin});

  final RouteSession session;
  final VoidCallback onChooseOrigin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (session.computing) {
      return const Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Text('Строим маршрут…'),
        ],
      );
    }

    if (session.locationFailed) {
      return _Problem(
        text: 'Не удалось определить, где вы. Выберите, откуда идти.',
        action: TextButton(
          onPressed: onChooseOrigin,
          child: const Text('Выбрать откуда'),
        ),
      );
    }

    switch (session.result) {
      case null:
        return const SizedBox.shrink();
      case RouteFound(:final distanceMeters, :final durationSeconds):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatDuration(durationSeconds)} · '
              '${formatDistance(distanceMeters)}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 2),
            Text(
              session.mode == TravelMode.drive
                  ? 'Примерно, без учёта пробок и светофоров.'
                  : 'Примерно, при спокойном шаге.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      case RouteNotFound(:final reason, :final startDistanceMeters):
        return switch (reason) {
          RouteFailure.startOffNetwork => _Problem(
            text: session.origin is FromMyLocation
                ? 'Вы ${_farText(startDistanceMeters)}. Маршруты строятся '
                      'по дорогам Аральска — выберите, откуда идти.'
                : 'Точка отправления далеко от дорог города.',
            action: TextButton(
              onPressed: onChooseOrigin,
              child: const Text('Выбрать откуда'),
            ),
          ),
          RouteFailure.endOffNetwork => const _Problem(
            text: 'Это место далеко от дорог города, маршрут не построить.',
          ),
          RouteFailure.noPath => _Problem(
            text: session.mode == TravelMode.drive
                ? 'Не нашли проезд на машине. Попробуйте пешком.'
                : 'Не нашли путь между этими точками.',
          ),
        };
    }
  }

  static String _farText(double? meters) {
    if (meters == null) return 'далеко от Аральска';
    final km = meters / 1000;
    return km < 10
        ? 'в ${km.toStringAsFixed(1).replaceAll('.', ',')} км от дорог города'
        : 'в ${km.round()} км от Аральска';
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
        if (action case final action?)
          Align(alignment: Alignment.centerRight, child: action),
      ],
    );
  }
}
