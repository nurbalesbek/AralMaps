import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/not_implemented_view.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: const NotImplementedView(
        icon: Icons.person_outline,
        title: 'Профиль и настройки',
        message:
            'Аккаунты появятся в Фазе 9. Офлайн-карты и настройки — раньше.',
      ),
    );
  }
}
