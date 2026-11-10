import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/models.dart';
import '../logic/geo.dart';
import '../logic/opening_hours.dart';
import '../logic/routing.dart';
import '../logic/tips.dart';
import '../state/app_state.dart';
import '../state/route_state.dart';
import 'assistant_screen.dart';
import 'voice_call_screen.dart';
import 'pharmacy_screen.dart';
import 'theme.dart';
import 'widgets/intro_video_card.dart';
import 'widgets/common.dart';
import 'widgets/motion.dart';
import 'widgets/pharmacy_map.dart';
import 'widgets/promo_banners.dart';
import 'widgets/route_panel.dart';
import 'widgets/tips_carousel.dart';
import '../l10n/lang.dart';

/// Популярные запросы, пока лекарство не выбрано.
const popularDrugIds = [
  'paracetamol-500',
  'ibuprofen-200',
  'citramon-p',
  'no-spa-40',
  'nurofen-200',
  'suprastin-25',
  'smecta-3',
  'loratadin-10',
];

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
  static const _sheetInitial = 0.3;
  static const _sheetMax = 0.9;

  final _map = MapController();
  final _sheet = DraggableScrollableController();
  late final _flyer = MapFlyer(_map, this);

  bool _mapReady = false;
  double _height = 0;
  String? _lastDrugId;
  LocationStatus? _lastLocationStatus;
  RouteResult? _lastRoute;

  @override
  void dispose() {
    _flyer.dispose();
    _sheet.dispose();
    _map.dispose();
    super.dispose();
  }

  void _afterStateChange(AppState state) {
    final drugId = state.selectedDrug?.id;
    if (drugId != _lastDrugId) {
      _lastDrugId = drugId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitResults(state));
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
        padding: EdgeInsets.fromLTRB(48, 190, 48, _height * _sheetInitial + 40),
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
            tr(context, 'Геолокация недоступна. Расстояния считаем от площади Ала-Тоо.'),
          ),
        ),
      );
    }
    _flyToUser(state);
  }

  void _onMarkerTap(AppState state, PharmacyResult r) {
    state.highlightPharmacy(r.pharmacy.id);
    _flyer.flyTo(
      LatLng(r.pharmacy.lat, r.pharmacy.lng),
      math.max(_map.camera.zoom, 15),
    );
  }

  void _openPharmacy(PharmacyResult r) {
    AppScope.read(context).highlightPharmacy(r.pharmacy.id);
    Navigator.of(context)
        .push(flipRoute(PharmacyScreen(pharmacyId: r.pharmacy.id)));
  }

  void _onTipAction(AppState state, TipAction action) {
    switch (action) {
      case SelectDrugAction(:final drug):
        state.selectDrug(drug);
      case OpenPharmacyAction(:final pharmacyId):
        state.highlightPharmacy(pharmacyId);
        Navigator.of(context)
            .push(flipRoute(PharmacyScreen(pharmacyId: pharmacyId)));
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
    if (route == null) return;
    final state = AppScope.read(context);
    state.highlightPharmacy(pharmacy.id);
    route.buildTo(
      pharmacy,
      from: LatLng(state.userLat, state.userLng),
      fromDevice: state.hasDeviceLocation,
    );
  }

  bool _routeWasActive = false;

  /// Свёрнутая шторка: видна только ручка и строка поиска.
  double get _sheetMin => (92 / _height).clamp(0.06, _sheetInitial - 0.01);

  /// Нажали на карту — шторка уезжает вниз, остаётся только поиск.
  void _collapseSheet() {
    final route = RouteScope.read(context);
    if ((route?.active ?? false) || !_sheet.isAttached) return;
    _sheet.animateTo(
      _sheetMin,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Высота карточки маршрута (меряется после отрисовки).
  double _routePanelHeight = 300;

  /// Высота шторки с карточкой маршрута: ровно под карточку (плюс ручка
  /// и отступы), чтобы снизу не было пустоты, а карта оставалась видна.
  double get _routeSheet =>
      ((_routePanelHeight + 44) / _height).clamp(0.2, 0.75);

  void _onRoutePanelHeight(double h) {
    if ((h - _routePanelHeight).abs() < 1) return;
    _routePanelHeight = h;
    final route = RouteScope.read(context);
    if ((route?.active ?? false) && _sheet.isAttached) {
      _sheet.jumpTo(_routeSheet);
    }
  }

  /// Маршрут готов — показываем его целиком над шторкой.
  void _afterRouteChange(RouteState? route) {
    // Маршрут закрыли — шторка возвращается в обычное положение.
    final active = route?.active ?? false;
    if (_routeWasActive && !active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sheet.isAttached) {
          _sheet.animateTo(
            _sheetInitial,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    _routeWasActive = active;

    final result = route?.result;
    if (identical(result, _lastRoute)) return;
    _lastRoute = result;
    if (result == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapReady || !mounted) return;
      if (_sheet.isAttached) {
        _sheet.animateTo(
          _routeSheet,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
      _flyer.flyToFit(
        CameraFit.coordinates(
          coordinates: result.points,
          maxZoom: 17,
          padding: EdgeInsets.fromLTRB(48, 190, 72, _height * _routeSheet + 24),
        ),
      );
    });
  }

  void _showRouteOnMap(RouteState route) {
    if (_sheet.isAttached) {
      _sheet.animateTo(
        _routeSheet,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
    final points = route.result?.points;
    if (_mapReady && points != null && points.length > 1) {
      _flyer.flyToFit(
        CameraFit.coordinates(
          coordinates: points,
          maxZoom: 17,
          padding: EdgeInsets.fromLTRB(
            32,
            190,
            48,
            _height * _routeSheet + 24,
          ),
        ),
      );
    }
  }

  void _openAssistant() {
    showAssistantSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final route = RouteScope.maybeOf(context);
    _afterStateChange(state);
    _afterRouteChange(route);

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
              Positioned.fill(
                child: PharmacyMap(
                  controller: _map,
                  results: state.results,
                  userPoint: LatLng(state.userLat, state.userLng),
                  showUser: state.hasDeviceLocation,
                  highlightedId: state.highlightedPharmacyId,
                  animationKey:
                      '${state.selectedDrug?.id}|${state.onlyOpen}|${state.chainFilter.length}',
                  onMarkerTap: (r) => _onMarkerTap(state, r),
                  onPopupTap: _openPharmacy,
                  onMapTap: () {
                    state.highlightPharmacy(null);
                    _collapseSheet();
                  },
                  route: route?.result,
                  routeTargetId: route?.target?.id,
                  onRouteTap: route == null
                      ? null
                      : (r) => _startRoute(r.pharmacy),
                ),
              ),
              // Верх: стеклянная панель (профиль, приветствие, ассистент)
              // и строка быстрых фильтров.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopPanel(
                        onProfile: widget.onOpenProfile,
                        onAssistant: _openAssistant,
                        onCall: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => const VoiceCallScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // «Где я» — справа над шторкой, едет вместе с ней.
              AnimatedBuilder(
                animation: _sheet,
                builder: (context, child) {
                  final size = _sheet.isAttached ? _sheet.size : _sheetInitial;
                  final fade = (1 - (size - 0.45) / 0.15).clamp(0.0, 1.0);
                  return Positioned(
                    right: 14,
                    bottom: _height * size + 12,
                    child: IgnorePointer(
                      ignoring: fade < 0.5,
                      child: Opacity(opacity: fade, child: child),
                    ),
                  );
                },
                child: _RoundButton(
                  icon: state.locationStatus == LocationStatus.loading
                      ? Icons.more_horiz
                      : Icons.near_me_outlined,
                  tooltip: tr(context, 'Где я'),
                  onTap: () => _onLocate(state),
                ),
              ),
              DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _sheetInitial,
                minChildSize: _sheetMin,
                maxChildSize: _sheetMax,
                snap: true,
                snapSizes: const [_sheetInitial],
                builder: (context, scroll) => _Sheet(
                  controller: scroll,
                  searchBar: Row(
                    children: [
                      Expanded(
                        child: _SearchPill(
                          drug: state.selectedDrug,
                          onTap: () => widget.onOpenSearch(),
                          onVoice: () => widget.onOpenSearch(voice: true),
                          onClear: state.clearDrug,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _RoundButton(
                        icon: Icons.tune,
                        tooltip: tr(context, 'Фильтры'),
                        badge: state.activeFilterCount,
                        onTap: () => showFiltersSheet(context),
                      ),
                    ],
                  ),
                  onOpenPharmacy: _openPharmacy,
                  onTipAction: (a) => _onTipAction(state, a),
                  route: route,
                  onRoutePanelHeight: _onRoutePanelHeight,
                  onShowRouteMap: route == null
                      ? null
                      : () => _showRouteOnMap(route),
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

class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.drug,
    required this.onTap,
    required this.onVoice,
    required this.onClear,
  });

  final Drug? drug;
  final VoidCallback onTap;
  final VoidCallback onVoice;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final d = drug;
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 14),
              // Логотип делает 3D-оборот при каждом новом выборе лекарства.
              Spin3D(key: ValueKey(d?.id), child: const LogoMark(size: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    d == null ? tr(context, 'Найти лекарство') : d.title,
                    key: ValueKey(d?.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      color: d == null ? AppColors.textMuted : AppColors.text,
                      fontWeight: d == null ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr(context, d == null ? 'Голосовой поиск' : 'Сбросить'),
                onPressed: d == null ? onVoice : onClear,
                icon: Icon(
                  d == null ? Icons.mic_none : Icons.close,
                  color: d == null ? AppColors.green : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
        elevation: 6,
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

/// Кнопка ассистента — объёмная зелёная сфера.
class _AssistantOrb extends StatelessWidget {
  const _AssistantOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [Color(0xFF6BD47F), AppColors.green, AppColors.greenDark],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x552E9F46),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
    );
  }
}

// ---------------------------------------------------------------------------
// Шторка
// ---------------------------------------------------------------------------

class _Sheet extends StatefulWidget {
  const _Sheet({
    required this.controller,
    required this.onOpenPharmacy,
    required this.onTipAction,
    this.route,
    this.onShowRouteMap,
    this.onRoutePanelHeight,
    this.searchBar,
  });

  final ScrollController controller;
  final ValueChanged<PharmacyResult> onOpenPharmacy;
  final ValueChanged<TipAction> onTipAction;

  /// Активный маршрут — тогда в шторке панель маршрута.
  final RouteState? route;
  final VoidCallback? onShowRouteMap;
  final ValueChanged<double>? onRoutePanelHeight;

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
      decoration: BoxDecoration(
        color: showingRoute ? AppColors.surface : AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ListView(
        controller: widget.controller,
        padding: showingRoute
            ? const EdgeInsets.fromLTRB(18, 10, 18, 16)
            : const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
            _MeasureHeight(
              onChange: (h) => widget.onRoutePanelHeight?.call(h),
              child: RoutePanel(
                route: route!,
                onClose: route.clear,
                onShowMap: widget.onShowRouteMap,
                isFavorite: state.isFavoritePharmacy(route.target!.id),
                onToggleFavorite: () =>
                    state.toggleFavoritePharmacy(route.target!.id),
              ),
            )
          else ...[
            if (widget.searchBar != null) ...[
              widget.searchBar!,
              const SizedBox(height: 14),
            ],
            ..._content(context, state),
          ],
        ],
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
    final results = state.results;
    final widgets = <Widget>[
      drug != null
          ? _DrugHeader(drug: drug, count: results.length)
          : const _Popular(),
      const SizedBox(height: 14),
    ];
    final filtered = state.activeFilterCount > 0;
    if (drug == null && !_showAll && !filtered) {
      widgets
        ..add(const IntroVideoCard())
        ..add(const SizedBox(height: 16))
        ..add(
          TipsCarousel(
            tips: buildTips(
              catalog: state.catalog!,
              userLat: state.userLat,
              userLng: state.userLng,
              now: state.now,
              lang: langOf(context).name,
            ),
            onAction: widget.onTipAction,
          ),
        )
        ..add(const SizedBox(height: 22))
        ..add(_Caption(tr(context, 'ПОЛЕЗНОЕ РЯДОМ')))
        ..add(
          PromoBanners(catalog: state.catalog!, onDrugPicked: state.selectDrug),
        )
        ..add(const SizedBox(height: 22))
        ..add(
          _AllPharmaciesButton(
            count: results.length,
            onTap: () => setState(() => _showAll = true),
          ),
        )
        ..add(const SizedBox(height: 16))
        ..add(
          _Footnote(
            isDemo: state.catalog?.isDemo ?? false,
            fromCenter: !state.hasDeviceLocation,
          ),
        );
      return widgets;
    }
    if (drug == null) {
      widgets.add(
        Row(
          children: [
            Expanded(
              child: _Caption(
                'РЯДОМ · ${results.length} ${_pharmacyWord(results.length).toUpperCase()}',
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

class _AllPharmaciesButton extends StatelessWidget {
  const _AllPharmaciesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressTilt(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_pharmacy_outlined, color: AppColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(context, 'Все аптеки рядом'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    ),
  );
}

class _DrugHeader extends StatelessWidget {
  const _DrugHeader({required this.drug, required this.count});

  final Drug drug;
  final int count;

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
              tooltip: fav ? 'Убрать из избранного' : 'В избранное',
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Caption('$count ${_pharmacyWord(count)}'.toUpperCase()),
            ),
            _SortSwitch(value: state.sort, onChanged: state.setSort),
          ],
        ),
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

class _Popular extends StatelessWidget {
  const _Popular();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog!;
    final recent = state.recentDrugs;
    final ids = [
      ...recent.map((d) => d.id),
      ...popularDrugIds.where((id) => !recent.any((d) => d.id == id)),
    ];
    final drugs = [for (final id in ids) ?catalog.drug(id)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: drugs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = drugs[i];
              final isRecent = i < recent.length;
              return ActionChip(
                avatar: isRecent
                    ? const Icon(
                        Icons.history,
                        size: 16,
                        color: AppColors.textMuted,
                      )
                    : null,
                label: Text(d.name, style: const TextStyle(fontSize: 15)),
                backgroundColor: AppColors.surface,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                onPressed: () => state.selectDrug(d),
              );
            },
          ),
        ),
      ],
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
                      '${formatDistance(result.distance)} · ${p.address}'
                      '${result.isOpen ? '' : ' · закрыто'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
      if (isDemo) 'Демо-данные: цены и наличие примерные',
      if (fromCenter) 'расстояние от площади Ала-Тоо',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: isDemo ? () => showDemoInfo(context) : null,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: const TextStyle(
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
          decoration: const BoxDecoration(
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
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                    color: onlyOpen ? AppColors.greenSoft : AppColors.background,
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
                                color: onlyOpen ? AppColors.green : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(context, 'Только открытые сейчас'),
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    tr(context, 'Скрыть закрытые аптеки'),
                                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
                            () => chains.contains(c) ? chains.remove(c) : chains.add(c),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: Text(tr(context, changes == 0 ? 'Показать все аптеки' : 'Показать')),
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
  const _ChainChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.greenSoft : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.green : AppColors.border, width: 1.2),
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
                    ? const Padding(
                        key: ValueKey(true),
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.check_rounded, size: 18, color: AppColors.green),
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


/// Стеклянная панель сверху: профиль, приветствие с городом, ассистент.
class _TopPanel extends StatelessWidget {
  const _TopPanel({required this.onProfile, required this.onAssistant, required this.onCall});

  final VoidCallback? onProfile;
  final VoidCallback onAssistant;

  /// Голосовой «звонок» ассистенту.
  final VoidCallback onCall;

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Доброе утро';
    if (h >= 12 && h < 18) return 'Добрый день';
    if (h >= 18 && h < 23) return 'Добрый вечер';
    return 'Доброй ночи';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pharmacies = state.catalog?.pharmacies ?? const <Pharmacy>[];
    final open = pharmacies.where((p) => isOpenAt(p, state.now)).length;
    final subtitle = tr(context, 'Открыто {open} из {total}',
        {'open': open, 'total': pharmacies.length});
    const radius = BorderRadius.all(Radius.circular(26));
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [BoxShadow(color: Color(0x1F0E2A1C), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: Colors.white.withValues(alpha: 0.78),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: Row(
              children: [
                Tooltip(
                  message: tr(context, 'Профиль'),
                  child: GestureDetector(
                    onTap: onProfile,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6BC57E), AppColors.greenDark],
                        ),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(context, _greeting(state.now)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Unbounded',
                          fontVariations: [FontVariation('wght', 700)],
                          fontSize: 15,
                          letterSpacing: -0.3,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: tr(context, 'Позвонить ассистенту'),
                  child: Material(
                    color: AppColors.greenSoft,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onCall,
                      child: const SizedBox.square(
                        dimension: 46,
                        child: Icon(Icons.call_rounded, color: AppColors.greenDark, size: 22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: tr(context, 'Ассистент'),
                  child: GestureDetector(
                    onTap: onAssistant,
                    child: const PulseRing(
                      size: 46,
                      color: AppColors.green,
                      child: SizedBox.square(
                        dimension: 46,
                        child: FittedBox(child: _AssistantOrb()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
