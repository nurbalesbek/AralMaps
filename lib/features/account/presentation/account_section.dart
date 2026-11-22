import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_routes.dart';
import '../../favorites/presentation/favorites_controller.dart';
import '../data/auth_service.dart';

/// "Account" block of the Profile tab.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Выйти из аккаунта?',
      text:
          'Избранное останется в аккаунте, а с этого телефона будет убрано. '
          'Войдите снова — и оно вернётся.',
      action: 'Выйти',
    );
    if (!ok) return;
    await ref.read(favoritesProvider.notifier).clearLocal();
    await ref.read(authServiceProvider).signOut();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      context,
      title: 'Удалить аккаунт?',
      text:
          'Аккаунт и всё избранное в нём будут удалены навсегда. '
          'Это нельзя отменить.',
      action: 'Удалить навсегда',
    );
    if (!ok) return;
    try {
      await ref.read(authServiceProvider).deleteAccount();
      await ref.read(favoritesProvider.notifier).clearLocal();
      messenger.showSnackBar(const SnackBar(content: Text('Аккаунт удалён')));
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String text,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(authServiceProvider);
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    if (!service.isAvailable) {
      return const ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Аккаунты недоступны в этой версии'),
        subtitle: Text('Избранное хранится только на этом телефоне.'),
      );
    }

    if (user == null) {
      return ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: const Text('Вы не вошли'),
        subtitle: const Text(
          'Войдите, чтобы избранное было в аккаунте и на других телефонах.',
        ),
        trailing: FilledButton(
          onPressed: () => context.push(AppRoutes.signIn),
          child: const Text('Войти'),
        ),
      );
    }

    final sync = ref.watch(favoritesSyncProvider);
    final (syncIcon, syncText) = switch (sync) {
      FavoritesSync.syncing => (Icons.sync, 'Синхронизация…'),
      FavoritesSync.synced => (
        Icons.cloud_done_outlined,
        'Избранное сохранено в аккаунте',
      ),
      FavoritesSync.pending => (
        Icons.cloud_off_outlined,
        'Нет связи — изменения отправятся позже',
      ),
      FavoritesSync.localOnly => (Icons.phone_android, 'Только на телефоне'),
    };

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle),
          title: Text(user.email ?? 'Аккаунт'),
          subtitle: Row(
            children: [
              Icon(syncIcon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(syncText)),
            ],
          ),
          trailing: sync == FavoritesSync.pending
              ? IconButton(
                  tooltip: 'Повторить синхронизацию',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).retrySync(),
                )
              : null,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Выйти'),
          onTap: () => _signOut(context, ref),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: theme.colorScheme.error,
          ),
          title: Text(
            'Удалить аккаунт',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          onTap: () => _deleteAccount(context, ref),
        ),
      ],
    );
  }
}
