import '../data/models.dart';
import 'drug_search.dart';
import 'geo.dart';
import 'opening_hours.dart';

/// Ответ ассистента. [drug] — если нашли лекарство, можно показать аптеки.
class AssistantReply {
  const AssistantReply(this.text, {this.drug});

  final String text;
  final Drug? drug;
}

const assistantGreeting =
    'Здравствуйте! Напишите название лекарства — подскажу, в какой аптеке '
    'оно есть рядом, где дешевле и какие есть аналоги.\n\n'
    'Я не врач и не подбираю лечение: по симптомам лучше обратиться к врачу или фармацевту.';

/// Слова, которые не являются названием лекарства.
const _stopWords = {
  'где', 'есть', 'купить', 'найти', 'найди', 'нужен', 'нужна', 'нужно', 'мне',
  'а', 'и', 'в', 'на', 'по', 'для', 'аптека', 'аптеке', 'аптеки', 'рядом',
  'ближайшая', 'ближайшую', 'дешевле', 'дешевый', 'дешевая', 'аналог', 'аналоги',
  'аналогов', 'цена', 'цену', 'сколько', 'стоит', 'наличие', 'наличии', 'ли',
  'какие', 'какой', 'подскажи', 'подскажите', 'пожалуйста', 'можно', 'хочу',
  'лекарство', 'таблетки', 'препарат', 'у', 'вас', 'есть?', 'привет', 'здравствуйте',
};

const _symptomWords = [
  'болит', 'боль', 'температур', 'кашель', 'кашля', 'насморк', 'тошнит', 'давлени',
  'лечить', 'лечение', 'выпить', 'принять', 'от чего', 'чем лечить', 'симптом',
  'аллерги', 'понос', 'изжог', 'простуд', 'грипп',
];

/// Ответ на сообщение пользователя. Работает только по каталогу,
/// медицинских советов не даёт.
AssistantReply assistantReply({
  required String message,
  required Catalog catalog,
  required double userLat,
  required double userLng,
  required DateTime now,
}) {
  final text = normalize(message);
  if (text.isEmpty) return const AssistantReply(assistantGreeting);

  final words = text.split(' ').where((w) => !_stopWords.contains(w)).toList();
  final drug = _findDrug(catalog, words);

  if (drug == null) {
    final isSymptom = _symptomWords.any(text.contains);
    if (isSymptom) {
      return const AssistantReply(
        'Я не подбираю лекарства по симптомам — это может быть опасно. '
        'Обратитесь к врачу или спросите фармацевта в аптеке.\n\n'
        'Если знаете название лекарства — напишите его, и я найду, где оно есть.',
      );
    }
    return const AssistantReply(
      'Не нашёл такого лекарства. Проверьте название или напишите действующее '
      'вещество, например «ибупрофен» или «парацетамол».',
    );
  }

  final offers = catalog.offersForDrug(drug.id);
  final buf = StringBuffer('${drug.title} (${drug.subtitle.toLowerCase()}).\n');
  if (drug.rx) buf.writeln('Отпускается только по рецепту врача.');

  if (offers.isEmpty) {
    buf.writeln('Сейчас нет ни в одной аптеке.');
  } else {
    double dist(Offer o) {
      final p = catalog.pharmacy(o.pharmacyId)!;
      return distanceMeters(userLat, userLng, p.lat, p.lng);
    }

    final openOffers =
        offers.where((o) => isOpenAt(catalog.pharmacy(o.pharmacyId)!, now)).toList();
    final pool = openOffers.isNotEmpty ? openOffers : offers;
    final nearest = pool.reduce((a, b) => dist(a) <= dist(b) ? a : b);
    final cheapest = pool.reduce((a, b) => a.price <= b.price ? a : b);

    String describe(Offer o) {
      final p = catalog.pharmacy(o.pharmacyId)!;
      return '${p.chain}, ${p.address} — ${o.price} сом, ${formatDistance(dist(o))}';
    }

    buf.writeln('Есть в ${offers.length} аптеках'
        '${openOffers.isEmpty ? ' (сейчас все закрыты)' : ', открыто сейчас: ${openOffers.length}'}.');
    buf.writeln('Ближайшая: ${describe(nearest)}.');
    if (cheapest.pharmacyId != nearest.pharmacyId) {
      buf.writeln('Дешевле всего: ${describe(cheapest)}.');
    }
  }

  final analogs = catalog.analogs(drug);
  if (analogs.isNotEmpty) {
    buf.write('Аналоги с тем же действующим веществом (${drug.inn}): ');
    buf.write(analogs.map((a) {
      final prices = catalog.offersForDrug(a.id).map((o) => o.price).toList();
      if (prices.isEmpty) return '${a.title} — нет в наличии';
      prices.sort();
      return '${a.title} — от ${prices.first} сом';
    }).join('; '));
    buf.writeln('.');
    buf.write('Перед заменой посоветуйтесь с врачом или фармацевтом.');
  }

  return AssistantReply(buf.toString().trim(), drug: drug);
}

Drug? _findDrug(Catalog catalog, List<String> words) {
  if (words.isEmpty) return null;
  // Сначала вся фраза целиком, потом каждое слово по отдельности.
  final whole = searchDrugs(catalog.drugs, words.join(' '), limit: 1);
  if (whole.isNotEmpty) return whole.first;
  // «но шпы» — название было через дефис, normalize его разделил.
  for (var i = 0; i + 1 < words.length; i++) {
    final joined = searchDrugs(catalog.drugs, words[i] + words[i + 1], limit: 1);
    if (joined.isNotEmpty) return joined.first;
  }
  for (final w in words) {
    if (w.length < 3) continue;
    final found = searchDrugs(catalog.drugs, w, limit: 1);
    if (found.isNotEmpty) return found.first;
  }
  return null;
}
