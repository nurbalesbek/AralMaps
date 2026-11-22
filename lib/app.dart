import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/favorites/presentation/favorites_controller.dart';

class AralMapApp extends ConsumerWidget {
  const AralMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Keep favorites alive app-wide, so syncing with the account runs at
    // start and right after sign-in, not only once a screen shows them.
    ref.listen(favoritesProvider, (_, _) {});

    return MaterialApp.router(
      title: 'AralMap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
