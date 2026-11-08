import 'package:apteka_ryadom/data/catalog_repository.dart';
import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/state/app_state.dart';
import 'package:apteka_ryadom/ui/widgets/profile_preferences.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show loadDemoCatalog;

class _Repository implements CatalogRepository {
  @override
  Future<Catalog> load() async => loadDemoCatalog();
}

class _StoredState extends AppState {
  _StoredState()
    : super(repository: _Repository(), clock: () => DateTime(2026, 11, 8, 12));
  @override
  Future<void> refreshLocation() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Search preferences survive restart and affect results', () async {
    SharedPreferences.setMockInitialValues({});
    final first = _StoredState();
    await first.init();
    await first.setSearchPreferences(onlyOpen: true, sort: SortMode.cheapest);
    await first.setHistoryEnabled(false);
    final reopened = _StoredState();
    await reopened.init();
    expect(reopened.onlyOpen, isTrue);
    expect(reopened.sort, SortMode.cheapest);
    expect(reopened.historyEnabled, isFalse);
    reopened.selectDrug(reopened.catalog!.drug('paracetamol-500')!);
    expect(reopened.results, isNotEmpty);
    expect(reopened.results.every((result) => result.isOpen), isTrue);
    final prices = reopened.results.map((result) => result.price!).toList();
    expect(prices, orderedEquals([...prices]..sort()));
    expect(reopened.recentDrugIds, isEmpty);
    first.dispose();
    reopened.dispose();
  });

  test(
    'Disabling history preserves old searches and stops recording new ones',
    () async {
      final state = AppState(
        repository: _Repository(),
        useDeviceServices: false,
      );
      await state.init();
      final drugs = state.catalog!.drugs;
      state.selectDrug(drugs[0]);
      await state.setHistoryEnabled(false);
      state.selectDrug(drugs[1]);
      expect(state.recentDrugIds, [drugs[0].id]);
      state.clearHistory();
      expect(state.recentDrugIds, isEmpty);
      await state.setHistoryEnabled(true);
      state.selectDrug(drugs[1]);
      expect(state.recentDrugIds, [drugs[1].id]);
      state.dispose();
    },
  );

  testWidgets(
    'Profile controls update search and copy real favorites on mobile',
    (tester) async {
      final state = AppState(
        repository: _Repository(),
        useDeviceServices: false,
      );
      await state.init();
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final drug = state.catalog!.drugs.first;
      final pharmacy = state.catalog!.pharmacies.first;
      state.toggleFavoriteDrug(drug.id);
      state.toggleFavoritePharmacy(pharmacy.id);
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ListenableBuilder(
                    listenable: state,
                    builder: (context, _) => ProfilePreferences(state: state),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Только открытые'));
      await tester.pumpAndSettle();
      expect(state.onlyOpen, isTrue);
      await tester.tap(find.text('Дешевле'));
      await tester.pumpAndSettle();
      expect(state.sort, SortMode.cheapest);
      await tester.tap(find.text('Сохранять историю'));
      await tester.pumpAndSettle();
      expect(state.historyEnabled, isFalse);
      await tester.ensureVisible(find.text('Скопировать избранное'));
      await tester.tap(find.text('Скопировать избранное'));
      await tester.pumpAndSettle();
      expect(copied, contains(drug.title));
      expect(copied, contains(pharmacy.address));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
