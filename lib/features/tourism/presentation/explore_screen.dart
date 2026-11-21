import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/not_implemented_view.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Обзор')),
      body: const NotImplementedView(
        icon: Icons.explore_outlined,
        title: 'Достопримечательности',
        message:
            'Раздел о местах Аральска появится после основных функций карты.',
      ),
    );
  }
}
