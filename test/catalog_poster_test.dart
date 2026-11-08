import 'package:apteka_ryadom/ui/widgets/category_grid.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show loadDemoCatalog;

void main() {
  testWidgets('Glass catalog fits mobile and opens categories', (tester) async {
    final catalog = loadDemoCatalog();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CategoryGrid(catalog: catalog, onDrugPicked: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text(catalog.categories.first).first);
    await tester.pumpAndSettle();
    expect(find.text(catalog.categories.first), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
