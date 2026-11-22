import 'package:material_ui/material_ui.dart';

import '../../search/domain/place.dart';

enum SightArea {
  town('В городе'),
  nearby('Окрестности');

  const SightArea(this.label);
  final String label;
}

@immutable
class SightSource {
  const SightSource(this.title, this.url);
  final String title;
  final String url;
}

/// A place worth visiting, with a short description written for the app
/// from the listed [sources]. Facts that sources disagree on are given as
/// ranges or with a year, never as one confident number.
@immutable
class Sight {
  const Sight({
    required this.id,
    required this.title,
    required this.area,
    required this.icon,
    required this.summary,
    required this.description,
    this.practical,
    this.latitude,
    this.longitude,
    required this.sources,
  });

  final String id;
  final String title;
  final SightArea area;
  final IconData icon;

  /// One line for the list.
  final String summary;

  /// Paragraphs for the detail screen.
  final List<String> description;

  /// How to get there / what to know before going.
  final String? practical;

  /// Null when no reliable position is known: then the app does not offer
  /// "show on map" rather than guess.
  final double? latitude;
  final double? longitude;

  final List<SightSource> sources;

  bool get hasLocation => latitude != null && longitude != null;

  /// For the map card and routing.
  Place toPlace() => Place(
    name: title,
    category: PlaceCategory.sight,
    latitude: latitude!,
    longitude: longitude!,
  );
}
