import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../search/domain/place.dart';
import '../data/photo_credits.dart';
import '../domain/sight.dart';

/// Accent colour: amber for the town, sea blue for the surroundings.
Color sightColor(Sight sight) => sight.area == SightArea.town
    ? PlaceCategory.sight.color
    : const Color(0xFF1F6F9F);

/// Photo of the sight, or — when there is no freely licensed photo — a
/// colour gradient with its icon (never a photo of another place).
class SightCover extends ConsumerWidget {
  const SightCover({super.key, required this.sight, this.iconSize = 48});

  final Sight sight;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(sightPhotosProvider).value?[sight.id];
    if (photo != null) {
      return Image.asset(
        photo.asset,
        fit: BoxFit.cover,
        semanticLabel: sight.title,
      );
    }
    final color = sightColor(sight);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.35)!],
        ),
      ),
      child: Center(
        child: Icon(
          sight.icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// Small credit line for a photo; opens the file page on Commons.
class PhotoCreditLine extends ConsumerWidget {
  const PhotoCreditLine({super.key, required this.sightId});

  final String sightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(sightPhotosProvider).value?[sightId];
    if (photo == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse(photo.credit.source),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          photo.credit.line,
          style: theme.textTheme.bodySmall?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
