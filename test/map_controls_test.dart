import 'package:apteka_ryadom/ui/theme.dart';
import 'package:apteka_ryadom/ui/widgets/map_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Кнопки карты: слои, приблизить, отдалить, где я', (
    tester,
  ) async {
    final calls = <String>[];
    MapLayer? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: MapControls(
                onLayers: () => showMapLayersSheet(
                  context,
                  current: MapLayer.scheme,
                  onSelected: (l) => chosen = l,
                ),
                onZoomIn: () => calls.add('+'),
                onZoomOut: () => calls.add('-'),
                onLocate: () => calls.add('me'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Приблизить'));
    await tester.tap(find.byTooltip('Отдалить'));
    await tester.tap(find.byTooltip('Где я'));
    expect(calls, ['+', '-', 'me']);

    await tester.tap(find.byTooltip('Слои карты'));
    await tester.pumpAndSettle();
    expect(find.text('Схема'), findsOneWidget);
    expect(find.text('Тёмная'), findsOneWidget);
    await tester.tap(find.text('Спутник'));
    await tester.pumpAndSettle();
    expect(chosen, MapLayer.satellite);
    expect(find.text('Спутник'), findsNothing); // окно закрылось
  });

  test('У каждой подложки свой адрес и подпись авторов', () {
    for (final l in MapLayer.values) {
      expect(l.urlTemplate, startsWith('https://'));
      expect(l.urlTemplate, contains('{z}'));
      expect(l.attribution, isNotEmpty);
    }
    expect(MapLayer.values.where((l) => l.muted), [MapLayer.scheme]);
  });
}
