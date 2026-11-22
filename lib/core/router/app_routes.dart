/// Central list of route paths, so screens never hardcode path strings.
abstract final class AppRoutes {
  static const map = '/map';
  static const favorites = '/favorites';
  static const explore = '/explore';
  static const profile = '/profile';
  static const search = '/search';

  /// Search opened with a query already typed (e.g. a category chip).
  static String searchFor(String query) =>
      '$search?q=${Uri.encodeQueryComponent(query)}';
  static const signIn = '/sign-in';

  static String sight(String id) => '$explore/sight/$id';
}
