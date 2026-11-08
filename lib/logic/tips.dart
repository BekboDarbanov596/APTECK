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
List<Tip> buildTips({
  required Catalog catalog,
  required double userLat,
  required double userLng,
  required DateTime now,
}) {
  final tips = <Tip>[];

  // 1. Экономия на аналоге с тем же действующим веществом.
  final saving = _bestSaving(catalog);
  if (saving != null) {
    final (cheap, cheapPrice, expensive, expensivePrice) = saving;
    tips.add(Tip(
      kind: TipKind.savings,
      title: 'Экономия до ${expensivePrice - cheapPrice} сом',
      text: '${cheap.name} — то же действующее вещество, что и ${expensive.name}: '
          'от $cheapPrice сом вместо $expensivePrice.',
      actionLabel: 'Где купить',
      action: SelectDrugAction(cheap),
    ));
  }

  // 2. Ближайшая круглосуточная аптека.
  final night = catalog.pharmacies.where((p) => p.isAroundTheClock).toList()
    ..sort((a, b) => distanceMeters(userLat, userLng, a.lat, a.lng)
        .compareTo(distanceMeters(userLat, userLng, b.lat, b.lng)));
  if (night.isNotEmpty) {
    final p = night.first;
    tips.add(Tip(
      kind: TipKind.nightPharmacy,
      title: 'Работает круглосуточно',
      text: '${p.chain}, ${p.address} — '
          '${formatDistance(distanceMeters(userLat, userLng, p.lat, p.lng))} от вас.',
      actionLabel: 'Открыть',
      action: OpenPharmacyAction(p.id),
    ));
  }

  // 3. Сколько аптек открыто прямо сейчас.
  final total = catalog.pharmacies.length;
  final open = catalog.pharmacies.where((p) => isOpenAt(p, now)).length;
  tips.add(Tip(
    kind: TipKind.openNow,
    title: 'Сейчас открыто $open из $total',
    text: open == total
        ? 'Все аптеки на карте сейчас работают.'
        : 'Покажем только те, куда можно зайти прямо сейчас.',
    actionLabel: open == total ? null : 'Только открытые',
    action: open == total ? null : const FilterAction(onlyOpen: true),
  ));

  // 4. Льготные лекарства по электронному рецепту (по плану исследования,
  // источник — kaktus.media, действует до конца 2026 года).
  if (now.isBefore(DateTime(2027)) && catalog.pharmacies.any((p) => p.chain == 'Эл Аман')) {
    tips.add(const Tip(
      kind: TipKind.benefit,
      title: 'Льготный э-рецепт',
      text: 'До 31 декабря 2026 льготные лекарства по электронным рецептам '
          'в Бишкеке отпускают только аптеки «Эл Аман».',
      actionLabel: 'Показать «Эл Аман»',
      action: FilterAction(chains: {'Эл Аман'}),
    ));
  }

  // 5–6. Подсказки без привязки к данным.
  tips.add(const Tip(
    kind: TipKind.searchHint,
    title: 'Ищите по веществу',
    text: 'Напишите «ибупрофен» — найдём все препараты с ним, '
        'а вы выберете подходящий по цене.',
    actionLabel: 'Найти',
    action: OpenSearchAction(),
  ));
  tips.add(const Tip(
    kind: TipKind.homeKit,
    title: 'Домашняя аптечка',
    text: 'Раз в полгода проверяйте сроки годности и храните лекарства '
        'там, где их не достанут дети.',
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
