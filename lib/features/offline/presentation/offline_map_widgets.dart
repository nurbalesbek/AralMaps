import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/offline_map_state.dart';
import 'offline_map_controller.dart';

/// Prompt on the map until the offline map is stored. Hidden while the
/// state is being checked and once the map is ready.
class OfflineMapBanner extends ConsumerWidget {
  const OfflineMapBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineMapProvider);
    final controller = ref.read(offlineMapProvider.notifier);
    final theme = Theme.of(context);

    final Widget body;
    switch (state) {
      case OfflineMapChecking() || OfflineMapReady():
        return const SizedBox.shrink();
      case OfflineMapNotDownloaded():
        body = _BannerRow(
          icon: Icons.download_for_offline_outlined,
          title: 'Карта без интернета',
          text: 'Скачайте карту Аральска один раз — потом она работает без связи.',
          actions: [
            TextButton(onPressed: onDismiss, child: const Text('Позже')),
            FilledButton(
              onPressed: controller.download,
              child: const Text('Скачать'),
            ),
          ],
        );
      case OfflineMapDownloading(:final progress, :final bytes):
        body = _DownloadProgress(progress: progress, bytes: bytes);
      case OfflineMapFailed(:final message):
        body = _BannerRow(
          icon: Icons.error_outline,
          iconColor: theme.colorScheme.error,
          title: 'Карта не скачана',
          text: message,
          actions: [
            TextButton(onPressed: onDismiss, child: const Text('Позже')),
            FilledButton(
              onPressed: controller.download,
              child: const Text('Повторить'),
            ),
          ],
        );
    }

    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      child: Padding(padding: const EdgeInsets.all(14), child: body),
    );
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.text,
    required this.actions,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(text, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final (i, a) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              a,
            ],
          ],
        ),
      ],
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress, required this.bytes});

  final double progress;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress * 100).clamp(0, 100).floor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Скачивание карты… $percent%', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress, minHeight: 6),
        const SizedBox(height: 6),
        Text(
          '${formatMegabytes(bytes)} · можно пользоваться картой',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Offline map section for the Profile tab: status and actions.
class OfflineMapSettingsTile extends ConsumerWidget {
  const OfflineMapSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineMapProvider);
    final controller = ref.read(offlineMapProvider.notifier);

    final (subtitle, trailing) = switch (state) {
      OfflineMapChecking() => ('Проверка…', null),
      OfflineMapNotDownloaded() => (
        'Не скачана. Без интернета карта не загрузится.',
        FilledButton(
          onPressed: controller.download,
          child: const Text('Скачать'),
        ),
      ),
      OfflineMapDownloading(:final progress) => (
        'Скачивание… ${(progress * 100).clamp(0, 100).floor()}%',
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      OfflineMapReady(:final bytes) => (
        'Скачана · ${formatMegabytes(bytes)}. Работает без интернета.',
        TextButton(
          onPressed: () => _confirmDelete(context, controller),
          child: const Text('Удалить'),
        ),
      ),
      OfflineMapFailed(:final message) => (
        message,
        FilledButton(
          onPressed: controller.download,
          child: const Text('Повторить'),
        ),
      ),
    };

    return ListTile(
      leading: const Icon(Icons.download_for_offline_outlined),
      title: const Text('Офлайн-карта Аральска'),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OfflineMapController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить офлайн-карту?'),
        content: const Text(
          'Без интернета карта перестанет загружаться. '
          'Скачать её снова можно в любой момент.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.delete();
  }
}
