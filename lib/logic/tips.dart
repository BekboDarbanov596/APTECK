import '../data/models.dart';
import 'geo.dart';
import 'opening_hours.dart';

enum TipKind { savings, nightPharmacy, openNow, benefit, searchHint, homeKit }

/// Что сделать по нажатию на карточку.
sealed class TipAction {
  const TipAction();
}

class SelectDrugAction extends TipAction {
  const SelectDrugAction(this.drug);
  final Drug drug;
}

class OpenPharmacyAction extends TipAction {
  const OpenPharmacyAction(this.pharmacyId);
  final String pharmacyId;
}

class FilterAction extends TipAction {
  const FilterAction({this.onlyOpen = false, this.chains = const {}});
  final bool onlyOpen;
  final Set<String> chains;
}

class OpenSearchAction extends TipAction {
  const OpenSearchAction();
}

class Tip {
  const Tip({
    required this.kind,
    required this.title,
    required this.text,
    this.actionLabel,
    this.action,
  });

  final TipKind kind;
  final String title;
  final String text;
  final String? actionLabel;
  final TipAction? action;
}

/// Карточки для главного экрана. Часть считается из каталога,
/// часть — справочные подсказки. Лечение не советуем.
/// [lang] — язык текста: 'ru', 'ky' или 'en'.
List<Tip> buildTips({
  required Catalog catalog,
  required double userLat,
  required double userLng,
  required DateTime now,
  String lang = 'ru',
}) {
  String t(String ru, String ky, String en) => switch (lang) {
        'ky' => ky,
        'en' => en,
        _ => ru,
      };
  String dist(double m) {
    final s = formatDistance(m);
    return lang == 'en' ? s.replaceAll(',', '.').replaceAll(' км', ' km').replaceAll(' м', ' m') : s;
  }

  final som = lang == 'en' ? 'som' : 'сом';
  final tips = <Tip>[];

  // 1. Экономия на аналоге с тем же действующим веществом.
  final saving = _bestSaving(catalog);
  if (saving != null) {
    final (cheap, cheapPrice, expensive, expensivePrice) = saving;
    final diff = expensivePrice - cheapPrice;
    tips.add(Tip(
      kind: TipKind.savings,
      title: t('Экономия до $diff сом', '$diff сомго чейин үнөмдөө', 'Save up to $diff som'),
      text: t(
        '${cheap.name} — то же действующее вещество, что и ${expensive.name}: '
            'от $cheapPrice сом вместо $expensivePrice.',
        '${cheap.name} — ${expensive.name} менен бир эле таасир берүүчү зат: '
            '$expensivePrice ордуна $cheapPrice сомдон баштап.',
        '${cheap.name} has the same active ingredient as ${expensive.name}: '
            'from $cheapPrice $som instead of $expensivePrice.',
      ),
      actionLabel: t('Где купить', 'Кайдан алуу', 'Where to buy'),
      action: SelectDrugAction(cheap),
    ));
  }

  // 2. Ближайшая круглосуточная аптека.
  final night = catalog.pharmacies.where((p) => p.isAroundTheClock).toList()
    ..sort((a, b) => distanceMeters(userLat, userLng, a.lat, a.lng)
        .compareTo(distanceMeters(userLat, userLng, b.lat, b.lng)));
  if (night.isNotEmpty) {
    final p = night.first;
    final d = dist(distanceMeters(userLat, userLng, p.lat, p.lng));
    tips.add(Tip(
      kind: TipKind.nightPharmacy,
      title: t('Работает круглосуточно', 'Күнү-түнү иштейт', 'Open 24/7'),
      text: t(
        '${p.chain}, ${p.address} — $d от вас.',
        '${p.chain}, ${p.address} — сизден $d.',
        '${p.chain}, ${p.address} — $d from you.',
      ),
      actionLabel: t('Открыть', 'Ачуу', 'Open'),
      action: OpenPharmacyAction(p.id),
    ));
  }

  // 3. Сколько аптек открыто прямо сейчас.
  final total = catalog.pharmacies.length;
  final open = catalog.pharmacies.where((p) => isOpenAt(p, now)).length;
  tips.add(Tip(
    kind: TipKind.openNow,
    title: t('Сейчас открыто $open из $total', 'Азыр $total дарыкананын $open ачык',
        '$open of $total open now'),
    text: open == total
        ? t('Все аптеки на карте сейчас работают.', 'Картадагы бардык дарыканалар азыр иштеп жатат.',
            'All pharmacies on the map are open now.')
        : t('Покажем только те, куда можно зайти прямо сейчас.',
            'Азыр эле кирсе боло турган дарыканаларды гана көрсөтөбүз.',
            "We'll show only the ones you can visit right now."),
    actionLabel: open == total ? null : t('Только открытые', 'Ачыктары гана', 'Open only'),
    action: open == total ? null : const FilterAction(onlyOpen: true),
  ));

  // 4. Льготные лекарства по электронному рецепту (по плану исследования,
  // источник — kaktus.media, действует до конца 2026 года).
  if (now.isBefore(DateTime(2027)) && catalog.pharmacies.any((p) => p.chain == 'Эл Аман')) {
    tips.add(Tip(
      kind: TipKind.benefit,
      title: t('Льготный э-рецепт', 'Жеңилдетилген э-рецепт', 'Subsidised e-prescription'),
      text: t(
        'До 31 декабря 2026 льготные лекарства по электронным рецептам '
            'в Бишкеке отпускают только аптеки «Эл Аман».',
        '2026-жылдын 31-декабрына чейин Бишкекте электрондук рецепт боюнча '
            'жеңилдетилген дарыларды «Эл Аман» дарыканалары гана берет.',
        'Until 31 December 2026, subsidised medicines on e-prescriptions in Bishkek '
            'are dispensed only by «Эл Аман» pharmacies.',
      ),
      actionLabel: t('Показать «Эл Аман»', '«Эл Аманды» көрсөтүү', 'Show «Эл Аман»'),
      action: const FilterAction(chains: {'Эл Аман'}),
    ));
  }

  // 5–6. Подсказки без привязки к данным.
  tips.add(Tip(
    kind: TipKind.searchHint,
    title: t('Ищите по веществу', 'Зат боюнча издеңиз', 'Search by ingredient'),
    text: t(
      'Напишите «ибупрофен» — найдём все препараты с ним, '
          'а вы выберете подходящий по цене.',
      '«ибупрофен» деп жазыңыз — анын бардык препараттарын табабыз, '
          'а сиз баасы ылайыгын тандайсыз.',
      'Type «ibuprofen» — we\'ll find every product with it '
          'and you pick the best price.',
    ),
    actionLabel: t('Найти', 'Табуу', 'Search'),
    action: const OpenSearchAction(),
  ));
  tips.add(Tip(
    kind: TipKind.homeKit,
    title: t('Домашняя аптечка', 'Үй дарылыгы', 'Home first-aid kit'),
    text: t(
      'Раз в полгода проверяйте сроки годности и храните лекарства '
          'там, где их не достанут дети.',
      'Жарым жылда бир жолу жарактуулук мөөнөтүн текшерип, дарыларды '
          'балдар жетпеген жерде сактаңыз.',
      'Every six months check expiry dates and keep medicines '
          'out of children\'s reach.',
    ),
  ));

  return tips;
}

/// Пара аналогов с наибольшей разницей минимальных цен.
(Drug, int, Drug, int)? _bestSaving(Catalog catalog) {
  final minPrice = <String, int>{};
  for (final o in catalog.offers) {
    final cur = minPrice[o.drugId];
    if (cur == null || o.price < cur) minPrice[o.drugId] = o.price;
  }
  (Drug, int, Drug, int)? best;
  for (final a in catalog.drugs) {
    for (final b in catalog.analogs(a)) {
      final pa = minPrice[a.id], pb = minPrice[b.id];
      if (pa == null || pb == null || pa >= pb) continue;
      if (best == null || pb - pa > best.$4 - best.$2) best = (a, pa, b, pb);
    }
  }
  if (best == null || best.$4 - best.$2 < 20) return null;
  return best;
}
