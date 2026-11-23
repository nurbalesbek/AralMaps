import 'package:material_ui/material_ui.dart';

import 'sight.dart';

/// One chapter of the town's story (Explore → «История Аральска»).
/// Every fact comes from [sources]; single-source facts are worded
/// carefully ("по данным…").
@immutable
class HistoryChapter {
  const HistoryChapter({
    required this.era,
    required this.title,
    required this.color,
    required this.paragraphs,
    this.photoKey,
    this.photoCaption,
    this.quote,
    required this.sources,
  });

  /// "1905", "1960-е — 2000-е"…
  final String era;
  final String title;
  final Color color;
  final List<String> paragraphs;

  /// Key in assets/photos/credits.json, if the chapter has a photo.
  final String? photoKey;
  final String? photoCaption;

  /// A short historical quote shown highlighted.
  final String? quote;

  final List<SightSource> sources;
}
