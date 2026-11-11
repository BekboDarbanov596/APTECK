import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../logic/geo.dart';
import '../logic/opening_hours.dart';

enum SortMode { nearest, cheapest }

enum LocationStatus { unknown, loading, device, denied, disabled, failed }

/// Аптека в результатах: цена есть, только если выбрано лекарство.
class PharmacyResult {
  const PharmacyResult({
    required this.pharmacy,
    required this.distance,
    required this.isOpen,
    this.price,
  });

  final Pharmacy pharmacy;
  final double distance;
  final bool isOpen;
  final int? price;
}

/// Общее состояние приложения. Экраны слушают его через [AppScope].
class AppState extends ChangeNotifier {
  AppState({
    required CatalogRepository repository,
    DateTime Function()? clock,
    this.useDeviceServices = true,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now;
  // ignore_for_file: prefer_initializing_formals

  final CatalogRepository _repository;
  final DateTime Function() _clock;

  /// false в тестах — не трогаем геолокацию и хранилище устройства.
  final bool useDeviceServices;

  static const _favDrugsKey = 'favorite_drugs';
  static const _favPharmaciesKey = 'favorite_pharmacies';
  static const _recentKey = 'recent_drugs';
  static const _onlyOpenKey = 'search_only_open';
  static const _sortKey = 'search_sort';
  static const _historyEnabledKey = 'history_enabled';

  Catalog? catalog;
  Object? loadError;
  bool get isLoading => catalog == null && loadError == null;

  double userLat = bishkekCenterLat;
  double userLng = bishkekCenterLng;
  LocationStatus locationStatus = LocationStatus.unknown;
  bool get hasDeviceLocation => locationStatus == LocationStatus.device;

  Drug? selectedDrug;
  String? highlightedPharmacyId;
  SortMode sort = SortMode.nearest;
  bool onlyOpen = false;
  bool historyEnabled = true;
  Set<String> chainFilter = {};

  final Set<String> favoriteDrugIds = {};
  final Set<String> favoritePharmacyIds = {};
  final List<String> recentDrugIds = [];

  DateTime get now => _clock();

  Future<void> init() async {
    await _loadCatalog();
    if (useDeviceServices) {
      await _loadPrefs();
      // Геолокацию не ждём: экран показываем сразу, расстояния обновятся.
      refreshLocation();
    }
  }

  Future<void> _loadCatalog() async {
    loadError = null;
    notifyListeners();
    try {
      catalog = await _repository.load();
    } catch (e, st) {
      debugPrint('Ошибка загрузки каталога: $e\n$st');
      loadError = e;
    }
    notifyListeners();
  }

  Future<void> retry() => _loadCatalog();

  Future<void> refreshLocation() async {
    locationStatus = LocationStatus.loading;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        locationStatus = LocationStatus.disabled;
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          locationStatus = LocationStatus.denied;
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 15),
            ),
          );
          userLat = pos.latitude;
          userLng = pos.longitude;
          locationStatus = LocationStatus.device;
        }
      }
    } catch (e) {
      debugPrint('Геолокация недоступна: $e');
      locationStatus = LocationStatus.failed;
    }
    notifyListeners();
  }

  // ---------- Выбор лекарства, сортировка, фильтры ----------

  void selectDrug(Drug drug) {
    selectedDrug = drug;
    highlightedPharmacyId = null;
    if (historyEnabled) {
      recentDrugIds
        ..remove(drug.id)
        ..insert(0, drug.id);
      if (recentDrugIds.length > 5) {
        recentDrugIds.removeRange(5, recentDrugIds.length);
      }
    }
    _savePrefs();
    notifyListeners();
  }

  void clearDrug() {
    selectedDrug = null;
    highlightedPharmacyId = null;
    notifyListeners();
  }

  void setSort(SortMode mode) {
    sort = mode;
    _savePrefs();
    notifyListeners();
  }

  void setFilters({required bool onlyOpen, required Set<String> chains}) {
    this.onlyOpen = onlyOpen;
    chainFilter = chains;
    _savePrefs();
    notifyListeners();
  }

  Future<void> setSearchPreferences({bool? onlyOpen, SortMode? sort}) async {
    if (onlyOpen != null) this.onlyOpen = onlyOpen;
    if (sort != null) this.sort = sort;
    notifyListeners();
    await _savePrefs();
  }

  Future<void> setHistoryEnabled(bool enabled) async {
    historyEnabled = enabled;
    notifyListeners();
    await _savePrefs();
  }

  int get activeFilterCount =>
      (onlyOpen ? 1 : 0) + (chainFilter.isEmpty ? 0 : 1);

  void highlightPharmacy(String? id) {
    highlightedPharmacyId = id;
    notifyListeners();
  }

  List<String> get chains {
    final c = catalog;
    if (c == null) return const [];
    return c.pharmacies.map((p) => p.chain).toSet().toList()..sort();
  }

  /// Аптеки с учётом выбранного лекарства, фильтров и сортировки.
  List<PharmacyResult> get results {
    final c = catalog;
    if (c == null) return const [];
    final now = this.now;
    final drug = selectedDrug;
    final prices = drug == null
        ? null
        : {for (final o in c.offersForDrug(drug.id)) o.pharmacyId: o.price};

    final list = <PharmacyResult>[];
    for (final p in c.pharmacies) {
      final price = prices?[p.id];
      if (prices != null && price == null) continue; // нет в наличии
      final open = isOpenAt(p, now);
      if (onlyOpen && !open) continue;
      if (chainFilter.isNotEmpty && !chainFilter.contains(p.chain)) continue;
      list.add(
        PharmacyResult(
          pharmacy: p,
          distance: distanceMeters(userLat, userLng, p.lat, p.lng),
          isOpen: open,
          price: price,
        ),
      );
    }

    int byDistance(PharmacyResult a, PharmacyResult b) =>
        a.distance.compareTo(b.distance);
    if (sort == SortMode.cheapest && drug != null) {
      list.sort((a, b) {
        final byPrice = a.price!.compareTo(b.price!);
        return byPrice != 0 ? byPrice : byDistance(a, b);
      });
    } else {
      list.sort(byDistance);
    }
    return list;
  }

  /// Сколько аптек вообще продают лекарство (без учёта фильтров).
  int availabilityCount(Drug drug) =>
      catalog?.offersForDrug(drug.id).length ?? 0;

  // ---------- Избранное и история ----------

  bool isFavoriteDrug(String id) => favoriteDrugIds.contains(id);
  bool isFavoritePharmacy(String id) => favoritePharmacyIds.contains(id);

  void toggleFavoriteDrug(String id) {
    if (!favoriteDrugIds.remove(id)) favoriteDrugIds.add(id);
    _savePrefs();
    notifyListeners();
  }

  void toggleFavoritePharmacy(String id) {
    if (!favoritePharmacyIds.remove(id)) favoritePharmacyIds.add(id);
    _savePrefs();
    notifyListeners();
  }

  List<Drug> get recentDrugs => [
    for (final id in recentDrugIds) ?catalog?.drug(id),
  ];

  void removeRecentDrug(Drug drug) {
    if (!recentDrugIds.remove(drug.id)) return;
    _savePrefs();
    notifyListeners();
  }

  void clearHistory() {
    recentDrugIds.clear();
    _savePrefs();
    notifyListeners();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      favoriteDrugIds.addAll(prefs.getStringList(_favDrugsKey) ?? const []);
      favoritePharmacyIds.addAll(
        prefs.getStringList(_favPharmaciesKey) ?? const [],
      );
      recentDrugIds.addAll(prefs.getStringList(_recentKey) ?? const []);
      onlyOpen = prefs.getBool(_onlyOpenKey) ?? false;
      sort = prefs.getString(_sortKey) == SortMode.cheapest.name
          ? SortMode.cheapest
          : SortMode.nearest;
      historyEnabled = prefs.getBool(_historyEnabledKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Не удалось прочитать настройки: $e');
    }
  }

  Future<void> _savePrefs() async {
    if (!useDeviceServices) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favDrugsKey, favoriteDrugIds.toList());
      await prefs.setStringList(
        _favPharmaciesKey,
        favoritePharmacyIds.toList(),
      );
      await prefs.setStringList(_recentKey, recentDrugIds.toList());
      await prefs.setBool(_onlyOpenKey, onlyOpen);
      await prefs.setString(_sortKey, sort.name);
      await prefs.setBool(_historyEnabledKey, historyEnabled);
    } catch (e) {
      debugPrint('Не удалось сохранить настройки: $e');
    }
  }
}

/// Даёт доступ к [AppState] из любого виджета: `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Без подписки на изменения — для обработчиков нажатий.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
