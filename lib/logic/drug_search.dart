import '../data/models.dart';

/// Поиск лекарств по названию, МНН и латинскому написанию.
/// Терпит регистр, «ё», лишние символы и небольшие опечатки.
List<Drug> searchDrugs(List<Drug> drugs, String query, {int limit = 20}) {
  final variants = _queryVariants(query);
  if (variants.isEmpty) return const [];

  final scored = <(Drug, int)>[];
  for (final drug in drugs) {
    var best = 0;
    for (final q in variants) {
      final s = _score(drug, q, q.split(' '));
      if (s > best) best = s;
    }
    if (best > 0) scored.add((drug, best));
  }

  // Ничего не нашли — пробуем с поправкой на опечатку.
  if (scored.isEmpty) {
    for (final drug in drugs) {
      if (variants.any((q) => _fuzzyMatch(drug, q.split(' ')))) {
        scored.add((drug, 1));
      }
    }
  }

  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : a.$1.name.compareTo(b.$1.name);
  });
  return scored.take(limit).map((e) => e.$1).toList();
}

/// Варианты запроса: как есть, без дефисов («но-шпы» → «ношпы»)
/// и без падежных окончаний («нурофена» → «нурофен», «ношпы» → «ношп»).
List<String> _queryVariants(String query) {
  final base = {normalize(query), normalize(query.replaceAll('-', ''))}
    ..removeWhere((q) => q.isEmpty);
  final result = <String>{...base};
  for (final q in base) {
    result.add(q.split(' ').map(_stripEnding).join(' '));
  }
  return result.toList();
}

final _ending = RegExp(r'(ами|ями|ой|ей|ом|ем|ов|ам|ям|ах|ях|[аяыиуюео])$');

String _stripEnding(String token) {
  if (token.length < 5 || !RegExp(r'[а-я]$').hasMatch(token)) return token;
  final stripped = token.replaceFirst(_ending, '');
  return stripped.length >= 4 ? stripped : token;
}

String normalize(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
    .trim();

List<String> _tokens(Drug d) =>
    normalize([d.name, d.inn, ...d.aliases].join(' ')).split(' ');

int _score(Drug drug, String q, List<String> queryTokens) {
  final name = normalize(drug.name);
  if (name == q) return 100;
  if (name.startsWith(q)) return 80;
  if (drug.aliases.any((a) => normalize(a).startsWith(q))) return 70;

  final tokens = _tokens(drug);
  final allMatch = queryTokens.every(
    (qt) => tokens.any((t) => t.startsWith(qt)),
  );
  if (!allMatch) return 0;
  // Совпало по действующему веществу — чуть ниже, чем по названию.
  return name.split(' ').any((t) => t.startsWith(queryTokens.first)) ? 60 : 40;
}

bool _fuzzyMatch(Drug drug, List<String> queryTokens) {
  final tokens = _tokens(drug);
  return queryTokens.every((qt) {
    if (qt.length < 4) return tokens.any((t) => t.startsWith(qt));
    final allowed = qt.length >= 7 ? 2 : 1;
    return tokens.any((t) {
      final prefix = t.length > qt.length ? t.substring(0, qt.length) : t;
      return levenshtein(prefix, qt) <= allowed;
    });
  });
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}
