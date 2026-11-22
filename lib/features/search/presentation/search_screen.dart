import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/places_repository.dart';
import '../domain/place.dart';

/// Full-screen place search. Pops with the chosen [Place], or null.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  static const _quickCategories = [
    PlaceCategory.pharmacy,
    PlaceCategory.health,
    PlaceCategory.grocery,
    PlaceCategory.food,
    PlaceCategory.education,
    PlaceCategory.transport,
    PlaceCategory.finance,
    PlaceCategory.fuel,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _query = text);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(placeSearchProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Улица, аптека, школа…',
            border: InputBorder.none,
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Очистить',
              icon: const Icon(Icons.close),
              onPressed: () => _setQuery(''),
            ),
        ],
      ),
      body: search.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const _Message(
          icon: Icons.error_outline,
          title: 'Не удалось загрузить список мест',
          text: 'Попробуйте перезапустить приложение.',
        ),
        data: (search) => _query.trim().isEmpty
            ? _QuickCategories(
                categories: _quickCategories,
                onSelected: (c) => _setQuery(c.label),
              )
            : _Results(results: search.search(_query)),
      ),
    );
  }
}

class _QuickCategories extends StatelessWidget {
  const _QuickCategories({required this.categories, required this.onSelected});

  final List<PlaceCategory> categories;
  final ValueChanged<PlaceCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Что найти', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in categories)
              ActionChip(
                avatar: Icon(c.icon, size: 18),
                label: Text(c.label),
                onPressed: () => onSelected(c),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const _DataNote(),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.results});

  final List<Place> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const _Message(
        icon: Icons.search_off,
        title: 'Ничего не найдено',
        text:
            'Попробуйте другое написание. Поиск знает только места, '
            'отмеченные в OpenStreetMap.',
      );
    }
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: results.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        if (i == results.length) {
          return const Padding(padding: EdgeInsets.all(16), child: _DataNote());
        }
        final place = results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            foregroundColor: theme.colorScheme.primary,
            child: Icon(place.category.icon, size: 20),
          ),
          title: Text(place.name),
          subtitle: Text(place.subtitle),
          onTap: () => context.pop(place),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              text,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DataNote extends StatelessWidget {
  const _DataNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Поиск работает без интернета. '
      'Данные © OpenStreetMap contributors (ODbL).',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
