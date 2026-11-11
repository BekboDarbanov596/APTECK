import 'dart:convert';
import 'dart:io';

import 'package:apteka_ryadom/data/catalog_repository.dart';
import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/state/app_state.dart';
import 'package:apteka_ryadom/ui/assistant_screen.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements CatalogRepository {
  @override
  Future<Catalog> load() async => Catalog.fromJson(
    jsonDecode(File('assets/demo_data.json').readAsStringSync())
        as Map<String, dynamic>,
  );
}

void main() {
  testWidgets(
    'Ассистент: окно снизу, ответ, «Показать на карте» закрывает окно',
    (tester) async {
      final state = AppState(
        repository: _Repo(),
        clock: () => DateTime(2026, 11, 9, 12),
        useDeviceServices: false,
      );
      await state.init();

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showAssistantSheet(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Ассистент'), findsOneWidget);
      // Под окном остаётся видна кнопка исходного экрана — это не отдельная страница.
      expect(find.text('open', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Где есть Нурофен?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ближайшая'), findsOneWidget);

      await tester.tap(find.text('Показать на карте'));
      await tester.pumpAndSettle();
      expect(find.text('Ассистент'), findsNothing);
      expect(state.selectedDrug?.id, 'nurofen-200');
    },
  );
}
