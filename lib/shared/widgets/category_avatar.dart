import 'package:material_ui/material_ui.dart';

import '../../features/search/domain/place.dart';

/// Round, category-coloured icon used in lists, cards and the map legend.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.radius = 20});

  final PlaceCategory category;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: category.color,
    foregroundColor: Colors.white,
    child: Icon(category.icon, size: radius),
  );
}
