import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:apteka_ryadom/ui/widgets/search_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show loadDemoCatalog;

void main() {
  final catalog = loadDemoCatalog();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 320,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Чем помочь: четыре плитки открывают свои действия', (
    tester,
  ) async {
    final actions = <String>[];
    await pump(
      tester,
      SearchHelpTiles(
        onSymptoms: () => actions.add('symptoms'),
        onCompare: () => actions.add('compare'),
        onOpenNow: () => actions.add('open'),
        onPrescription: () => actions.add('prescription'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Чем помочь?'), findsOneWidget);
    for (final title in [
      'По симптомам',
      'Сравнить цены',
      'Открыто сейчас',
      'Льготный рецепт',
    ]) {
      await tester.tap(find.text(title));
    }
    expect(actions, ['symptoms', 'compare', 'open', 'prescription']);
  });

  testWidgets('История отделена от списка и поддерживает удаление', (
    tester,
  ) async {
    final recent = [catalog.drug('smecta-3')!, catalog.drug('nurofen-200')!];
    Drug? removed;
    var cleared = false;
    await pump(
      tester,
      SearchHistoryCard(
        recent: recent,
        onPick: (_) {},
        onRemove: (drug) => removed = drug,
        onClear: () => cleared = true,
      ),
    );
    expect(find.text('Недавно искали'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(2));
    expect(find.text('Нурофен 200 мг'), findsOneWidget);
    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить из истории').first);
    expect(removed?.id, 'smecta-3');
    await tester.pump();
    await tester.tap(find.text('Очистить'));
    expect(cleared, isTrue);
  });

  testWidgets('Плитки разделов помещаются и открывают раздел', (tester) async {
    String? opened;
    var openNow = false;
    await pump(
      tester,
      SearchQuickTiles(
        catalog: catalog,
        openNowCount: 5,
        onOpenNow: () => openNow = true,
        onCategory: (c) => opened = c,
        iconFor: (_) => Icons.medication_outlined,
      ),
    );
    expect(tester.takeException(), isNull);
    for (final category in [
      'Диабет',
      'Простуда и нос',
      'Кожа и раны',
      'Аллергия',
    ]) {
      expect(find.text(category).hitTestable(), findsOneWidget);
    }
    await tester.tap(find.text('Диабет'));
    expect(opened, 'Диабет');
    final openNowTile = find.text('Открыто сейчас · 5');
    await tester.ensureVisible(openNowTile);
    await tester.pumpAndSettle();
    await tester.tap(openNowTile);
    expect(openNow, isTrue);
  });
}
