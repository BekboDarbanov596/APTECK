import 'dart:convert';
import 'dart:io';

import 'package:apteka_ryadom/data/catalog_repository.dart';
import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/l10n/lang.dart';
import 'package:apteka_ryadom/l10n/strings.dart';
import 'package:apteka_ryadom/logic/routing.dart';
import 'package:apteka_ryadom/state/app_state.dart';
import 'package:apteka_ryadom/state/route_state.dart';
import 'package:apteka_ryadom/ui/home_screen.dart';
import 'package:apteka_ryadom/ui/pharmacy_screen.dart';
import 'package:apteka_ryadom/ui/search_screen.dart';
import 'package:apteka_ryadom/ui/tabs.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements CatalogRepository {
  _Repo(this.catalog);
  final Catalog catalog;
  @override
  Future<Catalog> load() async => catalog;
}

final _cyr = RegExp('[А-Яа-яЁёҢңӨөҮү]');

/// Весь видимый текст: Text, RichText, подсказки полей и всплывающие подсказки.
Set<String> _visibleText(WidgetTester tester) {
  final out = <String>{};
  for (final w in tester.allWidgets) {
    if (w is Text) {
      out.add(w.data ?? w.textSpan?.toPlainText() ?? '');
    } else if (w is RichText) {
      out.add(w.text.toPlainText());
    } else if (w is Tooltip) {
      out.add(w.message ?? '');
    } else if (w is TextField) {
      out.add(w.decoration?.hintText ?? '');
      out.add(w.decoration?.labelText ?? '');
    }
  }
  return out..removeWhere((s) => s.trim().isEmpty);
}

void main() {
  final catalog = Catalog.fromJson(
    jsonDecode(File('assets/demo_data.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  // Данные каталога (названия лекарств, сети и адреса аптек) — имена собственные,
  // их не переводим. Всё остальное на английском должно быть по-английски.
  bool isData(String s) {
    for (final d in catalog.drugs) {
      for (final v in [d.title, d.subtitle, d.inn, d.name]) {
        if (v.isNotEmpty && s.contains(v)) return true;
      }
    }
    for (final p in catalog.pharmacies) {
      for (final v in [p.chain, p.address]) {
        if (v.isNotEmpty && s.contains(v)) return true;
      }
    }
    return false;
  }

  Future<List<String>> russianLeft(
    WidgetTester tester,
    Widget Function(AppState state) screen, {
    Future<void> Function(AppState state)? prepare,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(
      repository: _Repo(catalog),
      clock: () => DateTime(2026, 11, 8, 12),
      useDeviceServices: false,
    );
    await state.init();
    await prepare?.call(state);
    final lang = LangController(initial: AppLang.en, persist: false);
    final route = RouteState(RouteService());
    await tester.pumpWidget(
      LangScope(
        controller: lang,
        child: AppScope(
          state: state,
          child: RouteScope(
            route: route,
            child: MaterialApp(theme: buildTheme(), home: screen(state)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // Подпись авторов карты (flutter_map) в тестовом шрифте Ahem шире экрана —
    // это не про перевод, ошибку раскладки здесь пропускаем.
    while (tester.takeException() != null) {}
    final left = _visibleText(tester)
        .where((s) => _cyr.hasMatch(s) && !isData(s))
        .toList()
      ..sort();
    // Не ждём бесконечные анимации и сетевые плитки карты.
    await tester.pumpWidget(const SizedBox());
    // Догоняем таймеры загрузки плиток карты.
    await tester.pump(const Duration(seconds: 10));
    return left;
  }

  testWidgets('Поиск — по-английски', (tester) async {
    final left = await russianLeft(
      tester,
      (_) => SearchScreen(embedded: true, onPicked: (_) {}),
    );
    expect(left, isEmpty);
  });

  testWidgets('Профиль — по-английски', (tester) async {
    final left = await russianLeft(tester, (_) => const ProfileScreen());
    expect(left, isEmpty);
  });

  testWidgets('Избранное — по-английски', (tester) async {
    final left = await russianLeft(
      tester,
      (_) => FavoritesScreen(onDrugPicked: (_) {}),
    );
    expect(left, isEmpty);
  });

  testWidgets('Экран аптеки — по-английски', (tester) async {
    final left = await russianLeft(
      tester,
      (_) => PharmacyScreen(pharmacyId: catalog.pharmacies.first.id),
    );
    expect(left, isEmpty);
  });

  testWidgets('Карта со списком аптек — по-английски', (tester) async {
    final left = await russianLeft(
      tester,
      (_) => HomeScreen(onOpenSearch: ({bool voice = false}) {}),
      prepare: (state) async =>
          state.selectDrug(catalog.drug('paracetamol-500')!),
    );
    expect(left, isEmpty);
  });

  test('у каждой строки tr(…) в коде есть кыргызский и английский перевод', () {
    // tr(context, '…') и trNow('…') с русским текстом-ключом.
    final call = RegExp(r"""(?:tr\(\s*context,|trNow\()\s*'((?:[^'\\]|\\.)*)'""");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in call.allMatches(f.readAsStringSync())) {
        final key = m.group(1)!.replaceAll(r"\'", "'").replaceAll(r'\n', '\n');
        if (_cyr.hasMatch(key) && !uiStrings.containsKey(key)) {
          missing.add('${f.path}: $key');
        }
      }
    }
    expect(missing, isEmpty);
  });
}
