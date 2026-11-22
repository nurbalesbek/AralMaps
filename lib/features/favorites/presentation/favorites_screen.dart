import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/category_avatar.dart';
import '../../../shared/widgets/not_implemented_view.dart';
import '../../map/presentation/map_focus.dart';
import '../../search/domain/place.dart';
import 'favorites_controller.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Избранное')),
      body: switch (favorites) {
        AsyncData(:final value) when value.isEmpty => const NotImplementedView(
          icon: Icons.bookmark_border,
          title: 'Пока пусто',
          message:
              'Найдите место и нажмите на закладку в его карточке — '
              'оно появится здесь.',
        ),
        AsyncData(:final value) => _FavoritesList(places: value),
        AsyncError() => const NotImplementedView(
          icon: Icons.error_outline,
          title: 'Не удалось открыть избранное',
          message: 'Попробуйте перезапустить приложение.',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({required this.places});

  final List<Place> places;

  void _openOnMap(
    BuildContext context,
    WidgetRef ref,
    Place place,
    bool route,
  ) {
    ref.read(mapFocusProvider.notifier).request(place, withRoute: route);
    context.go(AppRoutes.map);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Place place) async {
    final controller = ref.read(favoritesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final index = await controller.remove(place);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('«${place.name}» удалено из избранного'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Вернуть',
            onPressed: () => controller.add(place, at: index),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: places.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final place = places[i];
        return Dismissible(
          key: ValueKey(place),
          direction: DismissDirection.endToStart,
          background: Container(
            color: theme.colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _remove(context, ref, place),
          child: ListTile(
            leading: CategoryAvatar(place.category),
            title: Text(place.name),
            subtitle: Text(place.subtitle),
            onTap: () => _openOnMap(context, ref, place, false),
            trailing: IconButton(
              tooltip: 'Маршрут к «${place.name}»',
              icon: const Icon(Icons.directions),
              color: theme.colorScheme.primary,
              onPressed: () => _openOnMap(context, ref, place, true),
            ),
          ),
        );
      },
    );
  }
}
