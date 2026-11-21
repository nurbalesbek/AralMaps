import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/not_implemented_view.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: NotImplementedView(
          icon: Icons.map_outlined,
          title: 'Карта Аральска',
          message: 'Отображение карты будет реализовано в Фазе 2.',
        ),
      ),
    );
  }
}
