import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/models.dart';
import '../logic/geo.dart';
import '../logic/routing.dart';
import '../logic/tips.dart';
import '../state/app_state.dart';
import '../state/route_state.dart';
import 'assistant_screen.dart';
import 'pharmacy_screen.dart';
import 'theme.dart';
import 'three/object3d.dart';
import 'widgets/category_grid.dart';
import 'widgets/intro_video_card.dart';
import 'widgets/common.dart';
import 'widgets/motion.dart';
import 'widgets/pharmacy_map.dart';
import 'widgets/route_panel.dart';
import 'widgets/tips_carousel.dart';

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
  const HomeScreen({super.key, required this.onOpenSearch});

  /// Открыть поиск. voice — сразу включить микрофон.
  final void Function({bool voice}) onOpenSearch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const _sheetInitial = 0.3;
  static const _sheetMin = 0.12;
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
      final becameDevice = state.locationStatus == LocationStatus.device &&
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
      for (final r in state.results.take(6)) LatLng(r.pharmacy.lat, r.pharmacy.lng),
      LatLng(state.userLat, state.userLng),
    ];
    if (points.length < 2) return;
    _flyer.flyToFit(CameraFit.coordinates(
      coordinates: points,
      maxZoom: 15,
      padding: EdgeInsets.fromLTRB(48, 150, 48, _height * _sheetInitial + 40),
    ));
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
      messenger.showSnackBar(const SnackBar(
        content: Text('Геолокация недоступна. Расстояния считаем от площади Ала-Тоо.'),
      ));
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
    Navigator.of(context).push(flipRoute(PharmacyScreen(pharmacyId: r.pharmacy.id)));
  }

  void _onTipAction(AppState state, TipAction action) {
    switch (action) {
      case SelectDrugAction(:final drug):
        state.selectDrug(drug);
      case OpenPharmacyAction(:final pharmacyId):
        state.highlightPharmacy(pharmacyId);
        Navigator.of(context).push(flipRoute(PharmacyScreen(pharmacyId: pharmacyId)));
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

  /// Маршрут готов — показываем его целиком над шторкой.
  void _afterRouteChange(RouteState? route) {
    final result = route?.result;
    if (identical(result, _lastRoute)) return;
    _lastRoute = result;
    if (result == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapReady || !mounted) return;
      if (_sheet.isAttached) {
        _sheet.animateTo(0.45, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      }
      _flyer.flyToFit(CameraFit.coordinates(
        coordinates: result.points,
        maxZoom: 17,
        padding: EdgeInsets.fromLTRB(48, 150, 72, _height * 0.45 + 30),
      ));
    });
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
      body: LayoutBuilder(builder: (context, constraints) {
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
                onMapTap: () => state.highlightPharmacy(null),
                route: route?.result,
                routeTargetId: route?.target?.id,
                onRouteTap: route == null ? null : (r) => _startRoute(r.pharmacy),
              ),
            ),
            // Мягкое осветление сверху, чтобы поиск читался на любой карте.
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 140,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCCF3F7F5), Color(0x00F3F7F5)],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
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
                      tooltip: 'Фильтры',
                      badge: state.activeFilterCount,
                      onTap: () => showFiltersSheet(context),
                    ),
                  ],
                ),
              ),
            ),
            // Кнопки справа едут вместе со шторкой и исчезают, когда она открыта.
            AnimatedBuilder(
              animation: _sheet,
              builder: (context, child) {
                final size = _sheet.isAttached ? _sheet.size : _sheetInitial;
                final fade = (1 - (size - 0.4) / 0.2).clamp(0.0, 1.0);
                return Positioned(
                  right: 8,
                  bottom: _height * size + 4,
                  child: IgnorePointer(
                    ignoring: fade < 0.5,
                    child: Opacity(opacity: fade, child: child),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Tooltip(
                    message: 'Ассистент',
                    child: GestureDetector(
                      onTap: _openAssistant,
                      child: const PulseRing(
                        size: 52,
                        color: AppColors.green,
                        child: _AssistantOrb(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 22, bottom: 8),
                    child: _RoundButton(
                      icon: state.locationStatus == LocationStatus.loading
                          ? Icons.more_horiz
                          : Icons.near_me_outlined,
                      tooltip: 'Где я',
                      onTap: () => _onLocate(state),
                    ),
                  ),
                ],
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
                onOpenPharmacy: _openPharmacy,
                onTipAction: (a) => _onTipAction(state, a),
                route: route,
              ),
            ),
          ],
        );
      }),
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
      elevation: 6,
      shadowColor: const Color(0x26000000),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: SizedBox(
          height: 56,
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
                    d == null ? 'Найти лекарство' : d.title,
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
                tooltip: d == null ? 'Голосовой поиск' : 'Сбросить',
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
          BoxShadow(color: Color(0x552E9F46), blurRadius: 14, offset: Offset(0, 6)),
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
  });

  final ScrollController controller;
  final ValueChanged<PharmacyResult> onOpenPharmacy;
  final ValueChanged<TipAction> onTipAction;

  /// Активный маршрут — тогда в шторке панель маршрута.
  final RouteState? route;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  /// Без выбранного лекарства список аптек свёрнут в одну кнопку.
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: ListView(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFCCD5CF),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (widget.route?.active ?? false)
            RoutePanel(route: widget.route!, onClose: widget.route!.clear)
          else
            ..._content(context, state),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, AppState state) {
    if (state.loadError != null) {
      return [
        MessageView(
          icon: Icons.wifi_off,
          title: 'Не удалось загрузить данные',
          text: 'Проверьте подключение к интернету.',
          actionLabel: 'Повторить',
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
      drug != null ? _DrugHeader(drug: drug, count: results.length) : const _Popular(),
      const SizedBox(height: 14),
    ];
    final filtered = state.activeFilterCount > 0;
    if (drug == null && !_showAll && !filtered) {
      widgets
        ..add(const IntroVideoCard())
        ..add(const SizedBox(height: 16))
        ..add(TipsCarousel(
          tips: buildTips(
            catalog: state.catalog!,
            userLat: state.userLat,
            userLng: state.userLng,
            now: state.now,
          ),
          onAction: widget.onTipAction,
        ))
        ..add(const SizedBox(height: 22))
        ..add(const _Caption('КАТАЛОГ'))
        ..add(CategoryGrid(catalog: state.catalog!, onDrugPicked: state.selectDrug))
        ..add(const SizedBox(height: 22))
        ..add(_AllPharmaciesButton(
          count: results.length,
          onTap: () => setState(() => _showAll = true),
        ))
        ..add(const SizedBox(height: 16))
        ..add(_Footnote(
          isDemo: state.catalog?.isDemo ?? false,
          fromCenter: !state.hasDeviceLocation,
        ));
      return widgets;
    }
    if (drug == null) {
      widgets.add(Row(
        children: [
          Expanded(
            child: _Caption(
                'РЯДОМ · ${results.length} ${_pharmacyWord(results.length).toUpperCase()}'),
          ),
          if (_showAll && !filtered)
            TextButton(
              onPressed: () => setState(() => _showAll = false),
              child: const Text('Советы'),
            ),
        ],
      ));
    }

    if (results.isEmpty) {
      final soldSomewhere = drug != null && state.availabilityCount(drug) > 0;
      widgets.add(drug != null && !soldSomewhere
          ? const MessageView(
              icon: Icons.medication_outlined,
              title: 'Сейчас нет ни в одной аптеке',
              text: 'Попробуйте аналог — спросите ассистента.',
            )
          : MessageView(
              icon: Icons.filter_alt_off_outlined,
              title: 'Нет аптек по фильтрам',
              actionLabel: 'Сбросить',
              onAction: () => state.setFilters(onlyOpen: false, chains: {}),
            ));
    } else {
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        widgets.add(FlipIn(
          key: ValueKey('${drug?.id}|${state.sort}|${r.pharmacy.id}'),
          delay: Duration(milliseconds: 45 * math.min(i, 10)),
          child: _PharmacyRow(
            result: r,
            highlighted: r.pharmacy.id == state.highlightedPharmacyId,
            onTap: () => widget.onOpenPharmacy(r),
          ),
        ));
      }
    }

    widgets.add(const SizedBox(height: 8));
    widgets.add(_Footnote(
      isDemo: state.catalog?.isDemo ?? false,
      fromCenter: !state.hasDeviceLocation,
    ));
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
                'Все аптеки рядом',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Text('$count', style: const TextStyle(fontSize: 16, color: AppColors.textMuted)),
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
            // Объект раздела, к которому относится лекарство.
            Object3D(
              key: ValueKey(drug.id),
              shape: shapeForCategory(drug.category),
              size: 68,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drug.title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
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
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
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
            Expanded(child: _Caption('$count ${_pharmacyWord(count)}'.toUpperCase())),
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
            alignment:
                value == SortMode.nearest ? Alignment.centerLeft : Alignment.centerRight,
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
                          color: value == mode ? AppColors.text : AppColors.textMuted,
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
        const Text('Что ищем?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
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
                    ? const Icon(Icons.history, size: 16, color: AppColors.textMuted)
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
  const _PharmacyRow({required this.result, required this.highlighted, required this.onTap});

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
                  color: result.isOpen ? AppColors.green : const Color(0xFFB8C2BC),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.chain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDistance(result.distance)} · ${p.address}'
                      '${result.isOpen ? '' : ' · закрыто'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: 12),
                Text(formatPrice(price),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
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
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Фильтры', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Только открытые сейчас', style: TextStyle(fontSize: 16)),
                value: onlyOpen,
                onChanged: (v) => setSheet(() => onlyOpen = v),
              ),
              const SizedBox(height: 8),
              const _Caption('АПТЕЧНЫЕ СЕТИ'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in state.chains)
                    FilterChip(
                      label: Text(c),
                      selected: chains.contains(c),
                      showCheckmark: false,
                      shape: const StadiumBorder(),
                      side: BorderSide.none,
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.greenSoft,
                      onSelected: (v) => setSheet(() => v ? chains.add(c) : chains.remove(c)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setSheet(() {
                        onlyOpen = false;
                        chains.clear();
                      }),
                      child: const Text('Сбросить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        state.setFilters(onlyOpen: onlyOpen, chains: chains);
                        Navigator.pop(context);
                      },
                      child: const Text('Показать'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
