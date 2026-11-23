import 'package:material_ui/material_ui.dart';

import '../domain/history.dart';
import '../domain/sight.dart';

const _osm = SightSource(
  'OpenStreetMap',
  'https://www.openstreetmap.org/#map=15/46.8000/61.6700',
);
const _wikiAral = SightSource(
  'Wikipedia: Aral, Kazakhstan',
  'https://en.wikipedia.org/wiki/Aral,_Kazakhstan',
);
const _wikiRuAral = SightSource(
  'Википедия: Аральск',
  'https://ru.wikipedia.org/wiki/Аральск',
);
const _silkAdvStation = SightSource(
  'Silk Adventures: здание железнодорожного вокзала в Аральске',
  'https://silkadv.com/en/content/zdanie-zheleznodorozhnogo-vokzala-v-aralske',
);
const _wikiAralSea = SightSource(
  'Wikipedia: Aral Sea',
  'https://en.wikipedia.org/wiki/Aral_Sea',
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
    title: 'Вокзал 1905 года и панно о рыбе для Поволжья',
    area: SightArea.town,
    icon: Icons.train_outlined,
    summary: 'Место, с которого началась история города',
    description: [
      'Станцию «Аральское Море» открыли в 1905 году на железной дороге '
          'Оренбург — Ташкент. С этого года отсчитывают официальную историю '
          'Аральска.',
      'На стене вокзала было большое панно с письмом Ленина аральским рыбакам '
          'от 7 октября 1921 года: в голод в Поволжье он просил их о помощи, и '
          'в декабре рыбаки отгрузили 14 вагонов рыбы.',
      'Важно: по данным русской Википедии, старое здание вокзала снесено в '
          'августе 2025 года. Сохранилось ли панно, нам неизвестно.',
    ],
    practical:
        'Прежде чем идти смотреть панно, узнайте у местных, что сейчас на '
        'месте старого здания.',
    latitude: 46.80091,
    longitude: 61.67509,
    sources: [_wikiRuAral, _silkAdvStation, _wikiAral, _osm],
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

/// «История Аральска» — the town's story in chapters, written for the app
/// from the cited pages (November 2026). Single-source facts are worded as
/// such; where sources disagree, ranges are given.
const historyChapters = <HistoryChapter>[
  HistoryChapter(
    era: '1817',
    title: 'Шесть колодцев',
    color: Color(0xFFB7791F),
    paragraphs: [
      'Задолго до города на этом месте, у северного берега огромного моря, '
          'стоял аул Алты-Кудук — «Шесть колодцев». В пустыне колодец значил '
          'жизнь, а шесть колодцев — место, где можно остаться.',
      'С 1870-х годов в документах появляется «Аральский посёлок». А само '
          'море называли Аралом — «островом»: когда-то на нём было больше '
          'тысячи ста островов.',
    ],
    sources: [_wikiRuAral, _wikiAral, _wikiAralSea],
  ),
  HistoryChapter(
    era: '1905',
    title: 'Город, который привезла железная дорога',
    color: Color(0xFF287E72),
    paragraphs: [
      'В 1899–1905 годах через степь проложили железную дорогу Оренбург — '
          'Ташкент. В 1905 году открылась станция «Аральское Море» — с этого '
          'года и отсчитывают официальную историю Аральска.',
      'Дорога соединила море с большой страной. Почти сразу русские купцы '
          'объединили рыболовные артели в акционерное общество «Хива», рядом '
          'выросли верфи и рыбные промыслы. Город поднялся на рыбе и рельсах.',
    ],
    sources: [_wikiRuAral, _wikiAral],
  ),
  HistoryChapter(
    era: '1921',
    title: '14 вагонов рыбы',
    color: Color(0xFFC0392B),
    quote: '«Жертвуйте, дорогие товарищи, аральские ловцы и рабочие»',
    paragraphs: [
      'Осенью 1921 года Поволжье охватил страшный голод. 7 октября Ленин '
          'написал письмо рыбакам Аральского моря и попросил о помощи.',
      'Ответ пришёл не словами: в декабре аральские рыбаки отгрузили '
          '14 вагонов рыбы. Эта история стала главной легендой города — '
          'много лет её рассказывало большое панно на стене вокзала.',
    ],
    sources: [_wikiRuAral, _silkAdvStation],
  ),
  HistoryChapter(
    era: '1938 — 1970-е',
    title: 'Город рыбаков',
    color: Color(0xFF2471A3),
    photoKey: 'history-fish-factory',
    photoCaption: 'Рыбзавод в Аральске, 2006 год',
    paragraphs: [
      'В 1938 году посёлок стал городом. В советские годы здесь работали '
          'судоремонтный завод и объединение «Аралрыбпром» с пятью '
          'рыбозаводами — они перерабатывали 45 % улова всего Аральского '
          'моря. Расцвет города пришёлся на 1970-е.',
      'Была в этой истории и тёмная страница. В 1971 году в Аральске '
          'вспыхнула оспа: заболели 10 человек, трое умерли. Источник болезни '
          'связывают с полигоном биологического оружия неподалёку. Город '
          'закрыли, и почти 50 000 жителей привили меньше чем за две недели.',
    ],
    sources: [_wikiRuAral, _wikiAral],
  ),
  HistoryChapter(
    era: '1960-е — 2000-е',
    title: 'Море уходит',
    color: Color(0xFF6D4C41),
    photoKey: 'history-sea-1964-2026',
    photoCaption: 'Аральское море из космоса: 1964 год (слева) и 2026 год',
    paragraphs: [
      'С 1960-х годов воду Амударьи и Сырдарьи стали массово забирать на '
          'орошение полей. Реки почти перестали доносить воду до моря, и Арал начал '
          'мелеть — год за годом всё быстрее.',
      'К 2007 году от моря, когда-то четвёртого по величине озера мира, '
          'осталось около 10 % прежней площади. Берег ушёл от Аральска почти '
          'на 100 км. Рыболовство рухнуло, суда остались лежать на песке, а '
          'из города много лет не было видно воды. Генсекретарь ООН Пан Ги Мун '
          'назвал высыхание Арала одной из худших экологических катастроф '
          'планеты.',
    ],
    sources: [_wikiAralSea, _wikiAral],
  ),
  HistoryChapter(
    era: '2005',
    title: 'Вода возвращается',
    color: Color(0xFF1F6F9F),
    photoKey: 'north-aral-sea',
    photoCaption: 'Северный Арал с самолёта, 2013 год',
    paragraphs: [
      'В августе 2005 года достроили Кокаральскую плотину длиной около 12 км. '
          'Она отделила Северный (Малый) Арал от южной части и удержала в нём '
          'воду Сырдарьи.',
      'Море откликнулось быстро: к 2008 году уровень поднялся на 12 метров, '
          'вода стала заметно преснее, и в Арал вернулась рыба — снова '
          'появился промысел. Берег приблизился к городу: сейчас до воды, по '
          'разным оценкам, 12–20 км.',
    ],
    sources: [_wikiAralSea, _wikiKokaral, _worldBank, _natGeo],
  ),
  HistoryChapter(
    era: 'Сегодня',
    title: 'Город, который ждёт море',
    color: Color(0xFF287E72),
    photoKey: 'harbour-fishermen-museum',
    photoCaption: 'Суда у бывшей гавани Аральска, 2009 год',
    paragraphs: [
      'В Аральске живут около 36 тысяч человек (перепись 2021 года). Город '
          'помнит, что был портом: у бывшей гавани стоят старые суда, а самое '
          'большое из них стало Музеем рыбаков.',
      'Пройдитесь по местам из раздела «Обзор» — от вокзала, с которого всё '
          'началось, до плотины, которая вернула воду.',
    ],
    sources: [_wikiRuAral, _lpFishermen],
  ),
];
