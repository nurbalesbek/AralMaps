import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/not_implemented_view.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Избранное')),
      body: const NotImplementedView(
        icon: Icons.bookmark_border,
        title: 'Пока пусто',
        message: 'Сохранение мест появится в Фазе 8.',
      ),
    );
  }
}
