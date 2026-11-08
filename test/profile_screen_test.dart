import 'package:apteka_ryadom/data/catalog_repository.dart';
import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/state/app_state.dart';
import 'package:apteka_ryadom/ui/profile_screen.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show loadDemoCatalog;

class _Repository implements CatalogRepository {
  @override
  Future<Catalog> load() async => loadDemoCatalog();
}

void main() {
  testWidgets('Profile fits mobile in every location state', (tester) async {
    final state = AppState(repository: _Repository(), useDeviceServices: false);
    await state.init();
    addTearDown(state.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      for (final location in LocationStatus.values) {
        state.locationStatus = location;
        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: buildTheme(),
              home: ProfileScreen(key: ValueKey('$width-$location')),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: '$width, $location');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Profile favorites, recent selection and clearing work', (
    tester,
  ) async {
    final state = AppState(repository: _Repository(), useDeviceServices: false);
    await state.init();
    addTearDown(state.dispose);
    final drug = state.catalog!.drugs.first;
    state.selectDrug(drug);
    var openedFavorites = false;
    Drug? picked;
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(),
          home: ProfileScreen(
            onOpenFavorites: () => openedFavorites = true,
            onDrugPicked: (drug) => picked = drug,
          ),
        ),
      ),
    );
    await tester.tap(find.text('В избранном'));
    expect(openedFavorites, isTrue);
    await tester.tap(find.text('Недавние поиски'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(drug.title));
    await tester.pumpAndSettle();
    expect(picked?.id, drug.id);
    await tester.tap(find.text('Недавние поиски'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Очистить историю поиска'));
    await tester.pumpAndSettle();
    expect(state.recentDrugIds, isEmpty);
    expect(
      find.text('Здесь появятся лекарства, которые вы искали.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
