import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/models.dart';
import '../logic/drug_search.dart';
import '../logic/geo.dart';
import '../logic/routing.dart';
import '../logic/tips.dart';
import '../state/app_state.dart';
import '../state/route_state.dart';
import 'assistant_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/motion.dart';
import 'widgets/pharmacy_map.dart';
import 'widgets/promo_banners.dart' show colorForCategory, iconForCategory;
import 'widgets/search_home.dart';
import 'widgets/drug_instruction.dart';
import 'widgets/route_panel.dart';
import 'widgets/category_grid.dart' show showCategorySheet;
import 'widgets/map_controls.dart';
import '../l10n/lang.dart';
import '../state/theme_state.dart';

/// Популярные запросы, пока лекарство не выбрано.
const popularDrugIds = [
  'nurofen-200',
  'smecta-3',
  'paracetamol-500',
  'ibuprofen-200',
  'citramon-p',
  'no-spa-40',
  'suprastin-25',
  'loratadin-10',
];

const _searchGreen = Color(0xFF087D1C);

/// Главный экран: карта на весь экран, поверх — только поиск,
/// кнопка фильтров и шторка со списком аптек.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenSearch, this.onOpenProfile});

  /// Открыть поиск. voice — сразу включить микрофон.
  final void Function({bool voice}) onOpenSearch;

  /// Открыть профиль (кнопка справа сверху).
  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Высота свёрнутой шторки: ручка + строка поиска.
  static const _collapsedPx = 112.0;

  final _map = MapController();
  final _sheetHeight = ValueNotifier<double>(_collapsedPx);
  late final _flyer = MapFlyer(_map, this);

  bool _mapReady = false;
  double _height = 0;
  String? _lastDrugId;
  LocationStatus? _lastLocationStatus;
  RouteResult? _lastRoute;

  /// Поиск прямо в шторке: текст, фокус и текущий запрос.
  final _searchText = TextEditingController();
  final _searchFocus = FocusNode();
  final _query = ValueNotifier<String>('');
  bool _searchExpanded = false;
  bool _comparePrices = false;

  @override
  void initState() {
    super.initState();
    _searchText.addListener(_onSearchChanged);
    _searchFocus.addListener(_onSearchFocus);
  }

  void _onSearchChanged() {
    final text = _searchText.text;
    // Название выбранного лекарства в поле — это не новый запрос.
    final selected = AppScope.read(context).selectedDrug;
    _query.value = selected != null && text == selected.title
        ? ''
        : text.trim();
  }

  void _onSearchFocus() {
    if (_searchFocus.hasFocus && !_searchExpanded) {
      setState(() => _searchExpanded = true);
    }
  }

  /// Выбрали лекарство из подсказок.
  void _pickDrug(Drug drug) {
    final state = AppScope.read(context);
    state.selectDrug(drug);
    _searchText.text = drug.title;
    _query.value = '';
    _searchFocus.unfocus();
    if (_searchExpanded) setState(() => _searchExpanded = false);
  }

  /// «Отмена» — как в 2ГИС: убрать клавиатуру, запрос и опустить шторку.
  void _cancelSearch() {
    final selected = AppScope.read(context).selectedDrug;
    _searchText.text = selected?.title ?? '';
    _query.value = '';
    _searchFocus.unfocus();
    if (_searchExpanded || _comparePrices) {
      setState(() {
        _searchExpanded = false;
        _comparePrices = false;
      });
    }
  }

  void _clearSearch() {
    _comparePrices = false;
    _searchText.clear();
    _query.value = '';
    AppScope.read(context).clearDrug();
  }

  @override
  void dispose() {
    _searchText.dispose();
    _searchFocus.dispose();
    _query.dispose();
    _flyer.dispose();
    _sheetHeight.dispose();
    _map.dispose();
    super.dispose();
  }

  void _afterStateChange(AppState state) {
    final drugId = state.selectedDrug?.id;
    if (drugId != _lastDrugId) {
      _lastDrugId = drugId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitResults(state);
        if (!mounted || _searchFocus.hasFocus) return;
        final title = state.selectedDrug?.title ?? '';
        if (_searchText.text != title) _searchText.text = title;
      });
    }
    if (state.locationStatus != _lastLocationStatus) {
      final becameDevice =
          state.locationStatus == LocationStatus.device &&
          _lastLocationStatus != LocationStatus.device;
      _lastLocationStatus = state.locationStatus;
      if (becameDevice && drugId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _flyToUser(state));
      }
    }
  }

  /// Перелёт камеры так, чтобы были видны ближайшие аптеки с лекарством.
  void _fitResults(AppState state) {
    if (!_mapReady || !mounted) return;
    final points = [
      for (final r in state.results.take(6))
        LatLng(r.pharmacy.lat, r.pharmacy.lng),
      LatLng(state.userLat, state.userLng),
    ];
    if (points.length < 2) return;
    _flyer.flyToFit(
      CameraFit.coordinates(
        coordinates: points,
        maxZoom: 15,
        padding: EdgeInsets.fromLTRB(48, 190, 48, _collapsedPx + 40),
      ),
    );
  }

  void _flyToUser(AppState state) {
    if (!_mapReady || !mounted) return;
    _flyer.flyTo(LatLng(state.userLat, state.userLng), 14.5);
  }

  Future<void> _onLocate(AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!state.hasDeviceLocation) await state.refreshLocation();
    if (!mounted) return;
    if (!state.hasDeviceLocation) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Геолокация недоступна. Расстояния считаем от площади Ала-Тоо.',
            ),
          ),
        ),
      );
    }
    _flyToUser(state);
  }

  void _openPharmacy(PharmacyResult r) {
    _startRoute(r.pharmacy);
  }

  void _onTipAction(AppState state, TipAction action) {
    switch (action) {
      case SelectDrugAction(:final drug):
        state.selectDrug(drug);
      case OpenPharmacyAction(:final pharmacyId):
        final pharmacy = state.catalog?.pharmacy(pharmacyId);
        if (pharmacy != null) _startRoute(pharmacy);
      case FilterAction(:final onlyOpen, :final chains):
        state.setFilters(onlyOpen: onlyOpen, chains: {...chains});
        _fitResults(state);
      case OpenSearchAction():
        widget.onOpenSearch();
    }
  }

  /// Построить маршрут до аптеки прямо на нашей карте.
  void _startRoute(Pharmacy pharmacy) {
    final route = RouteScope.read(context);
    if (route == null || route.target?.id == pharmacy.id) return;
    _cancelSearch();
    final state = AppScope.read(context);
    state.highlightPharmacy(pharmacy.id);
    if (_mapReady) {
      _flyer.flyTo(
        LatLng(pharmacy.lat, pharmacy.lng),
        math.max(_map.camera.zoom, 15),
      );
    }
    route.buildTo(
      pharmacy,
      from: LatLng(state.userLat, state.userLng),
      fromDevice: state.hasDeviceLocation,
    );
  }

  void _onSheetHeight(double height) {
    if (mounted) _sheetHeight.value = height;
  }

  /// Маршрут готов — показываем его над панелью.
  void _afterRouteChange(RouteState? route) {
    final result = route?.result;
    if (identical(result, _lastRoute)) return;
    _lastRoute = result;
    if (route == null || result == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(route.result, result)) _showRouteOnMap(route);
    });
  }

  void _showRouteOnMap(RouteState route) {
    final points = route.result?.points;
    if (_mapReady && points != null && points.length > 1) {
      _flyer.flyToFit(
        CameraFit.coordinates(
          coordinates: points,
          maxZoom: 17,
          padding: EdgeInsets.fromLTRB(
            32,
            _height * 0.22,
            48,
            math.min(_sheetHeight.value + 24, _height * 0.68),
          ),
        ),
      );
    }
  }

  /// Подложка карты.
  /// Подложка, выбранная вручную; null — по теме (ночью тёмная, днём схема).
  MapLayer? _chosenLayer;
  MapLayer get _layer => MapLayer.auto(dark: AppColors.dark, chosen: _chosenLayer);

  /// «+» / «−»: плавно на один уровень.
  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final cam = _map.camera;
    _flyer.flyTo(cam.center, (cam.zoom + delta).clamp(10.0, 18.0));
  }

  void _openAssistant() {
    showAssistantSheet(context);
  }

  Future<void> _openPrescriptionSearch() async {
    final search = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Льготный рецепт')),
        content: Text(
          tr(
            context,
            'Каталог показывает наличие и обычные цены. Возможность отпуска по льготному рецепту уточняйте в аптеке.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr(context, 'Закрыть')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr(context, 'Найти лекарство')),
          ),
        ],
      ),
    );
    if (mounted && search == true) _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final route = RouteScope.maybeOf(context);
    _afterStateChange(state);
    _afterRouteChange(route);
    final routeActive = route?.active ?? false;
    final showSearchContent =
        _searchExpanded ||
        state.selectedDrug != null ||
        state.activeFilterCount > 0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _height = constraints.maxHeight;
          if (!_mapReady) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _mapReady) return;
              _mapReady = true;
              if (state.selectedDrug != null) _fitResults(state);
            });
          }
          return Stack(
            children: [
              SizedBox.expand(
                child: PharmacyMap(
                  controller: _map,
                  results: state.results,
                  userPoint: LatLng(state.userLat, state.userLng),
                  showUser: state.hasDeviceLocation,
                  highlightedId: state.highlightedPharmacyId,
                  animationKey:
                      '${state.selectedDrug?.id}|${state.onlyOpen}|${state.chainFilter.length}',
                  onMarkerTap: _openPharmacy,
                  onPopupTap: _openPharmacy,
                  onMapTap: () {
                    if (!routeActive) _cancelSearch();
                  },
                  route: route?.result,
                  routeTargetId: route?.target?.id,
                  showPopup: false,
                  layer: _layer,
                  onRouteTap: route == null
                      ? null
                      : (r) => _startRoute(r.pharmacy),
                ),
              ),
              // Ассистент — «таблеткой» слева над шторкой, едет вместе с ней.
              AnimatedBuilder(
                animation: _sheetHeight,
                builder: (context, child) {
                  final size = _height > 0 ? _sheetHeight.value / _height : 1.0;
                  final fade = (1 - (size - 0.45) / 0.15).clamp(0.0, 1.0);
                  return Positioned(
                    left: 14,
                    bottom: _sheetHeight.value + 12,
                    child: IgnorePointer(
                      ignoring: fade < 0.5,
                      child: Opacity(opacity: fade, child: child),
                    ),
                  );
                },
                child: _AssistantPill(
                  label: tr(context, 'Ассистент'),
                  onTap: _openAssistant,
                ),
              ),
              // «Где я» — справа над шторкой, едет вместе с ней.
              AnimatedBuilder(
                animation: _sheetHeight,
                builder: (context, child) {
                  final size = _height > 0 ? _sheetHeight.value / _height : 1.0;
                  final fade = (1 - (size - 0.45) / 0.15).clamp(0.0, 1.0);
                  return Positioned(
                    right: 14,
                    bottom: _sheetHeight.value + 12,
                    child: IgnorePointer(
                      ignoring: fade < 0.5,
                      child: Opacity(opacity: fade, child: child),
                    ),
                  );
                },
                child: MapCircleButton(
                  tooltip: tr(context, 'Где я'),
                  onTap: () => _onLocate(state),
                  color: AppColors.green,
                  child: state.locationStatus == LocationStatus.loading
                      ? const Icon(Icons.more_horiz, color: Colors.white)
                      : const Icon(
                          Icons.near_me_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
              // Профиль — слева сверху, слои — справа сверху.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(
                    children: [
                      if (widget.onOpenProfile != null)
                        MapCircleButton(
                          tooltip: tr(context, 'Профиль'),
                          onTap: widget.onOpenProfile!,
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.text,
                            size: 24,
                          ),
                        ),
                      // Плашку «Демо-данные» над картой убрали: о примерных
                      // ценах говорят карточка аптеки и экран аптеки.
                      const Spacer(),
                      MapCircleButton(
                        tooltip: tr(context, 'Слои карты'),
                        onTap: () => showMapLayersSheet(
                          context,
                          current: _layer,
                          onSelected: (l) {
                            // «Схема» и «Тёмная» переключают всё приложение
                            // на светлую или ночную тему; «Спутник» — только карту.
                            final theme = ThemeScope.maybeOf(context);
                            if (theme != null && l != MapLayer.satellite) {
                              theme.set(
                                l == MapLayer.dark
                                    ? AppThemeMode.dark
                                    : AppThemeMode.light,
                              );
                              setState(() => _chosenLayer = null);
                            } else {
                              setState(() => _chosenLayer = l);
                            }
                          },
                        ),
                        child: Icon(
                          Icons.layers_outlined,
                          color: AppColors.text,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // «+» и «−» — отдельными кружками справа посередине.
              // Когда шторка с «где я» поднимается до них — плавно прячутся.
              AnimatedBuilder(
                animation: _sheetHeight,
                builder: (context, child) {
                  final zoomTop = _height * 0.38;
                  const zoomHeight = 108.0; // два кружка и промежуток
                  // Верх кнопки «где я»: над шторкой на 12 + её высота 48.
                  final locateTop = _height - _sheetHeight.value - 12 - 48;
                  final fade = ((locateTop - (zoomTop + zoomHeight) - 8) / 40)
                      .clamp(0.0, 1.0);
                  return Positioned(
                    right: 14,
                    top: zoomTop,
                    child: IgnorePointer(
                      ignoring: fade < 0.5,
                      child: Opacity(opacity: fade, child: child),
                    ),
                  );
                },
                child: Column(
                  children: [
                    MapCircleButton(
                      tooltip: tr(context, 'Приблизить'),
                      onTap: () => _zoomBy(1),
                      child: Icon(
                        Icons.add_rounded,
                        color: AppColors.text,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MapCircleButton(
                      tooltip: tr(context, 'Отдалить'),
                      onTap: () => _zoomBy(-1),
                      child: Icon(
                        Icons.remove_rounded,
                        color: AppColors.text,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _MeasureHeight(
                  onChange: _onSheetHeight,
                  child: _Sheet(
                    comparePrices: _comparePrices,
                    maxHeight:
                        _height *
                        (routeActive
                            ? 0.75
                            : _searchExpanded
                            ? 0.96
                            : 0.45),
                    showSearchContent: showSearchContent,
                    searchBar: Row(
                      children: [
                        Expanded(
                          child: _SearchField(
                            controller: _searchText,
                            focus: _searchFocus,
                            drug: state.selectedDrug,
                            onClear: _clearSearch,
                            onSubmit: (text) {
                              final found = searchDrugs(
                                state.catalog?.drugs ?? const [],
                                text,
                                limit: 1,
                              );
                              if (found.isNotEmpty) _pickDrug(found.first);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        ListenableBuilder(
                          listenable: _searchFocus,
                          builder: (context, _) {
                            final searching = _searchExpanded;
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: searching
                                  ? TextButton(
                                      key: const ValueKey('cancel'),
                                      onPressed: _cancelSearch,
                                      style: TextButton.styleFrom(
                                        foregroundColor: _searchGreen,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      child: Text(
                                        tr(context, 'Отмена'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  : _RoundButton(
                                      key: const ValueKey('filters'),
                                      icon: Icons.tune,
                                      tooltip: tr(context, 'Фильтры'),
                                      badge: state.activeFilterCount,
                                      onTap: () => showFiltersSheet(context),
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                    onOpenPharmacy: _openPharmacy,
                    onTipAction: (a) => _onTipAction(state, a),
                    onComparePrices: () {
                      setState(() => _comparePrices = true);
                      state.setSort(SortMode.cheapest);
                      _searchFocus.requestFocus();
                    },
                    onPrescription: _openPrescriptionSearch,
                    query: _query,
                    onPickDrug: _pickDrug,
                    route: route,
                    onShowRouteMap: route == null
                        ? null
                        : () => _showRouteOnMap(route),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Переход между экранами с 3D-поворотом страницы.
Route<void> flipRoute(Widget page) => PageRouteBuilder<void>(
  transitionDuration: const Duration(milliseconds: 480),
  reverseTransitionDuration: const Duration(milliseconds: 380),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, animation, _, child) {
    final t = Curves.easeOutCubic.transform(animation.value);
    return Opacity(
      opacity: t,
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: perspective(0.001)..rotateY(-0.5 * (1 - t)),
        child: child,
      ),
    );
  },
);

// ---------------------------------------------------------------------------
// Элементы поверх карты
// ---------------------------------------------------------------------------

/// Строка поиска прямо в шторке: печатаем сразу, без отдельной страницы.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.drug,
    required this.onClear,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final Drug? drug;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final d = drug;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasText = controller.text.isNotEmpty || d != null;
        return TextField(
          controller: controller,
          focusNode: focus,
          textInputAction: TextInputAction.search,
          onSubmitted: onSubmit,
          onTap: () {
            // Выбранное лекарство в поле — выделяем, чтобы сразу печатать новое.
            if (d != null && controller.text == d.title) {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            }
          },
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: tr(context, 'Найти лекарство…'),
            hintStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _searchGreen,
              size: 25,
            ),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: tr(context, 'Сбросить'),
                    onPressed: onClear,
                    icon: Icon(Icons.close, color: AppColors.textMuted),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(color: AppColors.green, width: 1.5),
            ),
          ),
        );
      },
    );
  }
}

/// Подсказки под строкой поиска: лекарства по названию, веществу, с опечатками.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.catalog,
    required this.onPick,
  });

  final String query;
  final Catalog? catalog;
  final ValueChanged<Drug> onPick;

  @override
  Widget build(BuildContext context) {
    final c = catalog;
    if (c == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final found = searchDrugs(c.drugs, query);
    if (found.isEmpty) {
      return MessageView(
        icon: Icons.search_off,
        title: tr(context, 'Ничего не нашли'),
        text: tr(
          context,
          'Проверьте название. Можно искать по действующему веществу, например «ибупрофен».',
        ),
      );
    }
    return Column(
      children: [
        for (final d in found)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onPick(d),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${d.subtitle}${d.rx ? ' · ${tr(context, 'по рецепту')}' : ''}',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: d.rx
                                    ? AppColors.orange
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (c.minPrice(d.id) case final price?)
                        Text(
                          '${tr(context, 'от')} ${formatPrice(price)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Text(
                          tr(context, 'нет в наличии'),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: AppColors.green,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: const Color(0x26000000),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          padding: const EdgeInsets.all(14),
          icon: Icon(icon, color: AppColors.text),
        ),
      ),
    );
  }
}

/// Кнопка ассистента: зелёная «таблетка» с искрой и подписью.
class _AssistantPill extends StatelessWidget {
  const _AssistantPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24343C2D),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(100),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            color: AppColors.greenFill,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Шторка
// ---------------------------------------------------------------------------

class _Sheet extends StatefulWidget {
  const _Sheet({
    required this.comparePrices,
    required this.maxHeight,
    required this.showSearchContent,
    required this.onOpenPharmacy,
    required this.onTipAction,
    required this.onComparePrices,
    required this.onPrescription,
    required this.query,
    required this.onPickDrug,
    this.route,
    this.onShowRouteMap,
    this.searchBar,
  });

  final double maxHeight;
  final bool comparePrices;
  final bool showSearchContent;
  final ValueChanged<PharmacyResult> onOpenPharmacy;
  final ValueChanged<TipAction> onTipAction;
  final VoidCallback onComparePrices;
  final VoidCallback onPrescription;

  /// Текст в строке поиска — пока он есть, вместо содержимого подсказки.
  final ValueListenable<String> query;
  final ValueChanged<Drug> onPickDrug;

  /// Активный маршрут — тогда в шторке панель маршрута.
  final RouteState? route;
  final VoidCallback? onShowRouteMap;

  /// Строка поиска с фильтрами — первая в шторке (как в 2ГИС).
  final Widget? searchBar;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  /// Без выбранного лекарства список аптек свёрнут в одну кнопку.
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final route = widget.route;
    final showingRoute = route?.active ?? false;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: showingRoute ? AppColors.surface : AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: AnimatedSize(
        alignment: Alignment.topCenter,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: ListView(
            key: ValueKey(showingRoute ? route!.target!.id : 'search'),
            shrinkWrap: true,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: showingRoute
                ? const EdgeInsets.fromLTRB(14, 10, 14, 12)
                : const EdgeInsets.fromLTRB(14, 10, 14, 16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: EdgeInsets.only(bottom: showingRoute ? 12 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCD5CF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (showingRoute)
                RoutePanel(
                  route: route!,
                  onClose: () {
                    state.highlightPharmacy(null);
                    route.clear();
                  },
                  onShowMap: widget.onShowRouteMap,
                  isFavorite: state.isFavoritePharmacy(route.target!.id),
                  onToggleFavorite: () =>
                      state.toggleFavoritePharmacy(route.target!.id),
                )
              else ...[
                if (widget.searchBar != null) widget.searchBar!,
                if (widget.showSearchContent) ...[
                  const SizedBox(height: 14),
                  ValueListenableBuilder<String>(
                    valueListenable: widget.query,
                    builder: (context, q, _) => q.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _content(context, state),
                          )
                        : _SearchResults(
                            query: q,
                            catalog: state.catalog,
                            onPick: widget.onPickDrug,
                          ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, AppState state) {
    if (state.loadError != null) {
      return [
        MessageView(
          icon: Icons.wifi_off,
          title: tr(context, 'Не удалось загрузить данные'),
          text: tr(context, 'Проверьте подключение к интернету.'),
          actionLabel: tr(context, 'Повторить'),
          onAction: state.retry,
        ),
      ];
    }
    if (state.isLoading) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Spin3D(turns: null, child: LogoMark(size: 40)),
          ),
        ),
      ];
    }

    final drug = state.selectedDrug;
    if (drug != null && !widget.comparePrices) {
      return [
        _DrugHeader(drug: drug),
        const SizedBox(height: 14),
        DrugInstruction(drug: drug),
      ];
    }
    final results = state.results;
    final widgets = <Widget>[
      if (drug != null) ...[
        _DrugHeader(drug: drug, count: results.length),
        const SizedBox(height: 14),
      ],
    ];
    final filtered = state.activeFilterCount > 0;
    // Без выбранного лекарства — как в 2ГИС: плитки-разделы и история
    // поиска. Их видно, когда шторку поднимают.
    if (drug == null && !_showAll && !filtered) {
      final catalog = state.catalog!;
      return widgets
        ..add(
          SearchQuickTiles(
            catalog: catalog,
            openNowCount: state.results.where((r) => r.isOpen).length,
            onOpenNow: () => state.setFilters(onlyOpen: true, chains: {}),
            onCategory: (category) => showCategorySheet(
              context,
              catalog: catalog,
              category: category,
              onDrugPicked: widget.onPickDrug,
            ),
            iconFor: iconForCategory,
          ),
        )
        ..add(const SizedBox(height: 27))
        ..add(
          SearchHelpTiles(
            onSymptoms: () => showAssistantSheet(context),
            onCompare: widget.onComparePrices,
            onOpenNow: () =>
                widget.onTipAction(const FilterAction(onlyOpen: true)),
            onPrescription: widget.onPrescription,
          ),
        )
        ..add(const SizedBox(height: 24))
        ..add(
          SearchHistoryCard(
            recent: state.recentDrugs,
            onPick: widget.onPickDrug,
            onRemove: state.removeRecentDrug,
            onClear: state.clearHistory,
          ),
        );
    }
    if (drug == null) {
      widgets.add(
        Row(
          children: [
            Expanded(
              child: _Caption(
                '${tr(context, 'РЯДОМ')} · ${results.length} '
                '${tr(context, _pharmacyWord(results.length)).toUpperCase()}',
              ),
            ),
            if (_showAll && !filtered)
              TextButton(
                onPressed: () => setState(() => _showAll = false),
                child: Text(tr(context, 'Советы')),
              ),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      final soldSomewhere = drug != null && state.availabilityCount(drug) > 0;
      widgets.add(
        drug != null && !soldSomewhere
            ? MessageView(
                icon: Icons.medication_outlined,
                title: tr(context, 'Сейчас нет ни в одной аптеке'),
                text: tr(context, 'Попробуйте аналог — спросите ассистента.'),
              )
            : MessageView(
                icon: Icons.filter_alt_off_outlined,
                title: tr(context, 'Нет аптек по фильтрам'),
                actionLabel: tr(context, 'Сбросить'),
                onAction: () => state.setFilters(onlyOpen: false, chains: {}),
              ),
      );
    } else {
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        widgets.add(
          FlipIn(
            key: ValueKey('${drug?.id}|${state.sort}|${r.pharmacy.id}'),
            delay: Duration(milliseconds: 45 * math.min(i, 10)),
            child: _PharmacyRow(
              result: r,
              highlighted: r.pharmacy.id == state.highlightedPharmacyId,
              onTap: () => widget.onOpenPharmacy(r),
            ),
          ),
        );
      }
    }

    widgets.add(const SizedBox(height: 8));
    widgets.add(
      _Footnote(
        isDemo: state.catalog?.isDemo ?? false,
        fromCenter: !state.hasDeviceLocation,
      ),
    );
    return widgets;
  }
}

String _pharmacyWord(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'аптека';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'аптеки';
  return 'аптек';
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    ),
  );
}

class _DrugHeader extends StatelessWidget {
  const _DrugHeader({required this.drug, this.count});

  final Drug drug;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final fav = state.isFavoriteDrug(drug.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Плитка с иконкой раздела, к которому относится лекарство.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorForCategory(drug.category).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                iconForCategory(drug.category),
                size: 28,
                color: colorForCategory(drug.category),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drug.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${drug.subtitle}${drug.rx ? ' · по рецепту' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: drug.rx ? AppColors.orange : AppColors.textMuted,
                      fontWeight: drug.rx ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tr(context, fav ? 'Убрать из избранного' : 'В избранное'),
              onPressed: () => state.toggleFavoriteDrug(drug.id),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Icon(
                  fav ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(fav),
                  color: fav ? AppColors.green : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        if (count case final pharmacyCount?) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Caption(
                  '$pharmacyCount ${_pharmacyWord(pharmacyCount)}'
                      .toUpperCase(),
                ),
              ),
              _SortSwitch(value: state.sort, onChanged: state.setSort),
            ],
          ),
        ],
      ],
    );
  }
}

/// Переключатель «Ближе / Дешевле» с пружинящим ползунком.
class _SortSwitch extends StatelessWidget {
  const _SortSwitch({required this.value, required this.onChanged});

  final SortMode value;
  final ValueChanged<SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const w = 84.0;
    return Container(
      height: 36,
      width: w * 2 + 6,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.greySoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: value == SortMode.nearest
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            child: Container(
              width: w,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(100),
                boxShadow: cardShadow,
              ),
            ),
          ),
          Row(
            children: [
              for (final (mode, label) in const [
                (SortMode.nearest, 'Ближе'),
                (SortMode.cheapest, 'Дешевле'),
              ])
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(mode),
                  child: SizedBox(
                    width: w,
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: value == mode
                              ? AppColors.text
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Строка аптеки: статус точкой, название, расстояние, цена — и всё.
class _PharmacyRow extends StatelessWidget {
  const _PharmacyRow({
    required this.result,
    required this.highlighted,
    required this.onTap,
  });

  final PharmacyResult result;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = result.pharmacy;
    final price = result.price;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressTilt(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlighted ? AppColors.green : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: result.isOpen
                      ? AppColors.green
                      : const Color(0xFFB8C2BC),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.chain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_eta(context, result.distance)}${formatDistance(result.distance)} · ${p.address}'
                      '${result.isOpen ? '' : ' · закрыто'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: 12),
                Text(
                  formatPrice(price),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else
                Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.isDemo, required this.fromCenter});

  final bool isDemo;
  final bool fromCenter;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (isDemo) tr(context, 'Демо-данные: цены и наличие примерные'),
      if (fromCenter) tr(context, 'расстояние от площади Ала-Тоо'),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: isDemo ? () => showDemoInfo(context) : null,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Фильтры
// ---------------------------------------------------------------------------

Future<void> showFiltersSheet(BuildContext context) {
  final state = AppScope.read(context);
  var onlyOpen = state.onlyOpen;
  final chains = {...state.chainFilter};
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) {
        final changes = (onlyOpen ? 1 : 0) + chains.length;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCD5CF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, 'Фильтры'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (changes > 0)
                        TextButton(
                          onPressed: () => setSheet(() {
                            onlyOpen = false;
                            chains.clear();
                          }),
                          child: Text(tr(context, 'Сбросить')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // «Открыто сейчас» — карточка с переключателем.
                  Material(
                    color: onlyOpen
                        ? AppColors.greenSoft
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setSheet(() => onlyOpen = !onlyOpen),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.schedule_rounded,
                                color: onlyOpen
                                    ? AppColors.green
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(context, 'Только открытые сейчас'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    tr(context, 'Скрыть закрытые аптеки'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: onlyOpen,
                              activeTrackColor: AppColors.green,
                              onChanged: (v) => setSheet(() => onlyOpen = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Caption(tr(context, 'АПТЕЧНЫЕ СЕТИ')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in state.chains)
                        _ChainChip(
                          label: c,
                          selected: chains.contains(c),
                          onTap: () => setSheet(
                            () => chains.contains(c)
                                ? chains.remove(c)
                                : chains.add(c),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () {
                      state.setFilters(onlyOpen: onlyOpen, chains: chains);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      tr(
                        context,
                        changes == 0 ? 'Показать все аптеки' : 'Показать',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ChainChip extends StatelessWidget {
  const _ChainChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.greenSoft : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.green : AppColors.border,
          width: 1.2,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected
                    ? Padding(
                        key: ValueKey(true),
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.green,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey(false)),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.greenDark : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Сообщает высоту ребёнка после каждой раскладки.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onChange, required super.child});

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _last) return;
    _last = h;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(h));
  }
}

/// «≈ 7 мин · » — примерное время для выбранного способа передвижения.
/// Для автобуса время не пишем: оно зависит от расписания.
String _eta(BuildContext context, double meters) {
  final mode = RouteScope.maybeOf(context)?.mode ?? TravelMode.walk;
  final seconds = mode.estimateSeconds(meters);
  if (seconds == null) return '';
  return '≈ ${formatDuration(seconds)} · ';
}
