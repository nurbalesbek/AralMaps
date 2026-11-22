import 'package:material_ui/material_ui.dart';

/// Kinds of places in the bundled OSM index (ids match tool/fetch_places.dart).
enum PlaceCategory {
  street('Улица', Icons.signpost_outlined, ['улица', 'көше', 'переулок']),
  district('Район', Icons.location_city, ['район', 'посёлок', 'площадь']),
  pharmacy('Аптека', Icons.local_pharmacy_outlined, ['аптека', 'дәріхана']),
  health('Медицина', Icons.local_hospital_outlined, [
    'больница',
    'поликлиника',
    'клиника',
    'аурухана',
    'емхана',
    'врач',
  ]),
  education('Образование', Icons.school_outlined, [
    'школа',
    'мектеп',
    'лицей',
    'гимназия',
    'детский сад',
    'балабақша',
    'колледж',
  ]),
  food('Еда', Icons.restaurant_outlined, [
    'кафе',
    'ресторан',
    'столовая',
    'еда',
    'асхана',
  ]),
  grocery('Продукты', Icons.local_grocery_store_outlined, [
    'продукты',
    'супермаркет',
    'магазин',
    'дүкен',
  ]),
  shop('Магазин', Icons.storefront_outlined, ['магазин', 'дүкен']),
  market('Рынок', Icons.shopping_basket_outlined, ['рынок', 'базар']),
  finance('Банк', Icons.account_balance_outlined, [
    'банк',
    'банкомат',
    'обмен',
  ]),
  transport('Транспорт', Icons.directions_bus_outlined, [
    'вокзал',
    'автовокзал',
    'станция',
    'автобус',
  ]),
  fuel('АЗС', Icons.local_gas_station_outlined, ['азс', 'заправка', 'бензин']),
  lodging('Гостиница', Icons.hotel_outlined, [
    'гостиница',
    'отель',
    'қонақ үй',
  ]),
  sight('Достопримечательность', Icons.photo_camera_outlined, [
    'достопримечательность',
    'памятник',
    'музей',
    'ескерткіш',
  ]),
  park('Парк', Icons.park_outlined, ['парк', 'сквер', 'саябақ']),
  leisure('Досуг', Icons.sports_soccer_outlined, ['стадион', 'спорт']),
  government('Госучреждение', Icons.account_balance, [
    'акимат',
    'әкімдік',
    'цон',
    'суд',
  ]),
  emergency('Экстренные службы', Icons.local_police_outlined, [
    'полиция',
    'пожарная',
  ]),
  post('Почта', Icons.local_post_office_outlined, ['почта', 'пошта']),
  religion('Религия', Icons.mosque_outlined, ['мечеть', 'церковь', 'мешіт']),
  other('Место', Icons.place_outlined, []);

  const PlaceCategory(this.label, this.icon, this.keywords);

  final String label;
  final IconData icon;

  /// Words (Russian and Kazakh) that find this category without a name match.
  final List<String> keywords;

  static PlaceCategory fromId(String id) => PlaceCategory.values.firstWhere(
    (c) => c.name == id,
    orElse: () => PlaceCategory.other,
  );
}

@immutable
class Place {
  const Place({
    required this.name,
    this.altNames = const [],
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  /// Main OSM `name` (often Kazakh or Russian, sometimes Latin).
  final String name;

  /// `name:ru` / `name:kk` when they differ from [name].
  final List<String> altNames;
  final PlaceCategory category;
  final double latitude;
  final double longitude;

  /// Second line in lists: category plus the other-language name, if any.
  String get subtitle => altNames.isEmpty
      ? category.label
      : '${category.label} · ${altNames.first}';

  /// Reads both the bundled index (`ru`, `kk`) and [toJson] output (`alt`).
  factory Place.fromJson(Map<String, dynamic> json) => Place(
    name: json['n'] as String,
    altNames: [
      if (json['alt'] case final List<dynamic> alt) ...alt.cast<String>(),
      if (json['ru'] case final String ru) ru,
      if (json['kk'] case final String kk) kk,
    ],
    category: PlaceCategory.fromId(json['c'] as String),
    latitude: (json['la'] as num).toDouble(),
    longitude: (json['lo'] as num).toDouble(),
  );

  Map<String, Object> toJson() => {
    'n': name,
    if (altNames.isNotEmpty) 'alt': altNames,
    'c': category.name,
    'la': latitude,
    'lo': longitude,
  };

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.name == name &&
      other.category == category &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, category, latitude, longitude);
}
