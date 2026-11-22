import 'package:material_ui/material_ui.dart';

import '../domain/sight.dart';

const _osm = SightSource(
  'OpenStreetMap',
  'https://www.openstreetmap.org/#map=15/46.8000/61.6700',
);
const _wikiAral = SightSource(
  'Wikipedia: Aral, Kazakhstan',
  'https://en.wikipedia.org/wiki/Aral,_Kazakhstan',
);
const _lpFishermen = SightSource(
  'Lonely Planet: Fishermen’s Museum',
  'https://www.lonelyplanet.com/kazakhstan/aral/attractions/fishermens-museum/a/poi-sig/1390346/356876',
);
const _lpHistory = SightSource(
  'Lonely Planet: History Museum',
  'https://www.lonelyplanet.com/kazakhstan/aral/attractions/history-museum/a/poi-sig/1384806/356876',
);
const _guideEverything = SightSource(
  'Everything Everywhere: A Guide to Visiting the Aral Sea in Kazakhstan',
  'https://everything-everywhere.com/a-guide-to-visiting-the-aral-sea-in-kazakhstan/',
);
const _darkTourism = SightSource(
  'Dark-tourism.com: Aralsk and the North Aral Sea',
  'https://dark-tourism.com/index.php/500-aralsk-and-the-north-aral-sea-kazakhstan',
);
const _wikiKokaral = SightSource(
  'Wikipedia: Dike Kokaral',
  'https://en.wikipedia.org/wiki/Dike_Kokaral',
);
const _worldBank = SightSource(
  'World Bank: Saving a Corner of the Aral Sea (2005)',
  'https://www.worldbank.org/en/results/2005/09/01/saving-a-corner-of-the-aral-sea',
);
const _natGeo = SightSource(
  'National Geographic: North Aral Sea restoration (2018)',
  'https://www.nationalgeographic.com/science/article/north-aral-sea-restoration-fish-kazakhstan',
);
const _wikiZhalanash = SightSource(
  'Wikipedia: Zhalanash',
  'https://en.wikipedia.org/wiki/Zhalanash',
);

/// Sights of Aral and around. Written for AralMap from the cited sources
/// (November 2026); details such as opening hours change, so they are not
/// given as facts.
const sights = <Sight>[
  Sight(
    id: 'railway-station',
    title: 'Вокзал и мозаика о рыбе для Поволжья',
    area: SightArea.town,
    icon: Icons.train_outlined,
    summary: 'Вокзал 1905 года с мозаикой о самом известном событии города',
    description: [
      'Железнодорожный вокзал Аральска построен в 1905 году и работает до сих '
          'пор.',
      'Внутри — большая мозаика о событии начала 1920-х годов: в голод в '
          'Поволжье Ленин обратился к аральским рыбакам, и они отправили туда '
          'несколько составов с рыбой. Год в источниках указывают по-разному — '
          '1920 или 1921.',
    ],
    practical: 'Вокзал действующий, мозаика — внутри здания.',
    latitude: 46.80091,
    longitude: 61.67509,
    sources: [_wikiAral, _darkTourism, _guideEverything, _osm],
  ),
  Sight(
    id: 'ship-monument',
    title: 'Памятник-кораблик аральским рыбакам',
    area: SightArea.town,
    icon: Icons.sailing_outlined,
    summary: 'Корабль на площади у вокзала — память о рыбацком прошлом',
    description: [
      'Памятник в виде корабля в честь аральских рыбаков стоит на площади '
          'рядом с вокзалом. Он напоминает, что Аральск был портом, пока море '
          'не отступило.',
    ],
    latitude: 46.80002,
    longitude: 61.67507,
    sources: [_osm, _guideEverything],
  ),
  Sight(
    id: 'harbour-fishermen-museum',
    title: 'Старая гавань и Музей рыбаков',
    area: SightArea.town,
    icon: Icons.anchor_outlined,
    summary: 'Суда на месте бывшей гавани, в самом большом — музей',
    description: [
      'Аральск был рыболовным портом, но море ушло, и от бывшей гавани до воды '
          'теперь далеко. У старой гавани оставлены несколько судов.',
      'Самое большое из них — часть Музея рыбаков: рыболовные снасти, картины, '
          'фотографии и карты советского времени. На палубу можно подняться.',
    ],
    practical:
        'Точка музея не отмечена в OpenStreetMap, поэтому на карте мы её не '
        'показываем. Часы работы и цену билета уточняйте на месте.',
    sources: [_lpFishermen, _wikiAral],
  ),
  Sight(
    id: 'history-museum',
    title: 'Краеведческий музей',
    area: SightArea.town,
    icon: Icons.museum_outlined,
    summary: 'Фотографии высыхания моря и коллекция рыб Арала',
    description: [
      'Небольшой музей: фотографии того, как высыхало море, картины и '
          'коллекция банок с разными видами рыб Аральского моря (около 15).',
    ],
    practical:
        'Точка музея не отмечена в OpenStreetMap. Часы работы уточняйте на '
        'месте.',
    sources: [_lpHistory],
  ),
  Sight(
    id: 'central-mosque',
    title: 'Центральная мечеть',
    area: SightArea.town,
    icon: Icons.mosque_outlined,
    summary: 'Главная мечеть города',
    description: ['Главная мечеть Аральска, в центре города.'],
    practical:
        'При посещении — закрытая одежда, обувь снимают у входа; во время '
        'намаза лучше не заходить с экскурсией.',
    latitude: 46.79836,
    longitude: 61.66759,
    sources: [_osm],
  ),
  Sight(
    id: 'north-aral-sea',
    title: 'Северный (Малый) Арал',
    area: SightArea.nearby,
    icon: Icons.water_outlined,
    summary: 'Море, которое начали возвращать',
    description: [
      'Когда-то море подходило к самому городу. По мере высыхания берег '
          'отступил почти на 100 км.',
      'После постройки Кокаральской плотины (2005) уровень Северного Арала '
          'поднялся, и берег снова приблизился к городу: по разным оценкам, '
          'до 12–20 км (данные 2015–2018 годов).',
    ],
    practical:
        'Точного «пляжа» в наших данных нет. Как и где лучше подъехать к '
        'воде, спрашивайте у местных или у гида.',
    sources: [_wikiKokaral, _natGeo, _wikiAral],
  ),
  Sight(
    id: 'kokaral-dam',
    title: 'Кокаральская плотина',
    area: SightArea.nearby,
    icon: Icons.horizontal_rule,
    summary: 'Плотина 2005 года, которая спасла северную часть моря',
    description: [
      'Плотина длиной около 12 км отделила Северный Арал от Южного. '
          'Строительство завершили в августе 2005 года при поддержке '
          'Всемирного банка; более ранние дамбы размывало в 1992 и 1998 '
          'годах.',
      'После этого уровень Северного Арала поднялся, вода стала менее '
          'солёной, и в море вернулась рыба.',
    ],
    practical:
        'Далеко от города и от населённых пунктов. Маршрут и состояние дороги '
        'уточняйте у местного гида; возьмите запас воды и топлива.',
    latitude: 46.09667,
    longitude: 60.79306,
    sources: [_wikiKokaral, _worldBank, _natGeo],
  ),
  Sight(
    id: 'zhalanash',
    title: 'Жаланаш — бывшее «кладбище кораблей»',
    area: SightArea.nearby,
    icon: Icons.directions_boat_outlined,
    summary: 'Бывшая рыбацкая деревня, где на песке стояли суда',
    description: [
      'Жаланаш был рыбацкой деревней на берегу Арала. Когда море ушло, суда '
          'остались стоять в пустыне — это место стало известно как «кладбище '
          'кораблей».',
      'Важно: по данным на 2017 год, корпуса судов почти все разрезаны на '
          'металлолом, остались лишь днища. Сейчас здесь живут в основном '
          'разведением верблюдов.',
    ],
    practical:
        'По дороге — около 60–70 км от Аральска (по разным источникам). '
        'Перед поездкой узнайте у местных, что сохранилось сейчас.',
    latitude: 46.65639,
    longitude: 61.12722,
    sources: [_wikiZhalanash, _guideEverything],
  ),
];
