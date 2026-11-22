/// Central list of route paths, so screens never hardcode path strings.
abstract final class AppRoutes {
  static const map = '/map';
  static const favorites = '/favorites';
  static const explore = '/explore';
  static const profile = '/profile';
  static const search = '/search';

  static String sight(String id) => '$explore/sight/$id';
}
