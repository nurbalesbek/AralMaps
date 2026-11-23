import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/photo_credits.dart';
import '../data/sights.dart';
import '../domain/history.dart';
import 'sight_visuals.dart';

/// «История Аральска»: the town's story as a timeline of chapters.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('История Аральска')),
      body: ListView(
        // + bottom inset: content stays above the floating tab bar.
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'От аула «Шесть колодцев» до моря, которое ушло на сто '
            'километров и начало возвращаться.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final (i, chapter) in historyChapters.indexed)
            _ChapterTile(
              chapter: chapter,
              isLast: i == historyChapters.length - 1,
            ),
          const SizedBox(height: 8),
          Text(
            'Текст написан для AralMap по открытым источникам — они указаны '
            'под каждой главой. Фото: Wikimedia Commons и NASA.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter, required this.isLast});

  final HistoryChapter chapter;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline: dot + line in the chapter colour.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: chapter.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: chapter.color.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: chapter.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      chapter.era,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(chapter.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (chapter.quote case final quote?) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: chapter.color.withValues(alpha: 0.08),
                        border: Border(
                          left: BorderSide(color: chapter.color, width: 4),
                        ),
                      ),
                      child: Text(
                        quote,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final p in chapter.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(p, style: theme.textTheme.bodyLarge),
                    ),
                  if (chapter.photoKey case final key?)
                    _ChapterPhoto(photoKey: key, caption: chapter.photoCaption),
                  _Sources(chapter: chapter),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterPhoto extends ConsumerWidget {
  const _ChapterPhoto({required this.photoKey, this.caption});

  final String photoKey;
  final String? caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(sightPhotosProvider).value?[photoKey];
    if (photo == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              photo.asset,
              fit: BoxFit.cover,
              width: double.infinity,
              semanticLabel: caption,
            ),
          ),
          if (caption case final c?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(c, style: theme.textTheme.bodyMedium),
            ),
          PhotoCreditLine(sightId: photoKey),
        ],
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.chapter});

  final HistoryChapter chapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Источники:', style: theme.textTheme.bodySmall),
        for (final s in chapter.sources)
          InkWell(
            onTap: () => launchUrl(
              Uri.parse(s.url),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              s.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}
