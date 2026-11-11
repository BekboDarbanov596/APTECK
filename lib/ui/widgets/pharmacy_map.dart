import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../logic/routing.dart';
import '../../logic/transit.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'map_controls.dart';
import 'motion.dart';
import 'transit_legs.dart';
import '../../l10n/lang.dart';

/// Карта на весь экран: аптеки «падают» на карту с 3D-переворотом,
/// выбранная поднимается, над ней всплывает подсказка с ценой.
/// Ночная карта: яркость инвертируется, оттенок сохраняется
/// (c' = 0.72·(c − 2·Y + 255) + 12, Y — яркость по Rec. 709).
const _nightMatrix = <double>[
  0.4139, -1.0299, -0.104, 0, 195.6, //
  -0.3061, -0.3099, -0.104, 0, 195.6, //
  -0.3061, -1.0299, 0.616, 0, 195.6, //
  0, 0, 0, 1, 0, //
];

class PharmacyMap extends StatelessWidget {
  const PharmacyMap({
    super.key,
    required this.controller,
    required this.results,
    required this.userPoint,
    required this.showUser,
    required this.highlightedId,
    required this.animationKey,
    required this.onMarkerTap,
    required this.onPopupTap,
    required this.onMapTap,
    this.layer = MapLayer.scheme,
    this.route,
    this.routeTargetId,
    this.onRouteTap,
    this.showPopup = true,
  });

  final MapController controller;
  final List<PharmacyResult> results;
  final LatLng userPoint;
  final bool showUser;
  final String? highlightedId;

  /// Меняется — метки заново «падают» (например, выбрали другое лекарство).
  final String animationKey;
  final ValueChanged<PharmacyResult> onMarkerTap;
  final ValueChanged<PharmacyResult> onPopupTap;
  final VoidCallback onMapTap;

  /// Подложка: схема, светлая или спутник.
  final MapLayer layer;

  /// Построенный маршрут — рисуется линией по улицам.
  final RouteResult? route;

  /// Аптека, к которой строится маршрут (подсказка над ней не показывается).
  final String? routeTargetId;

  /// Кнопка «Маршрут» в подсказке над аптекой.
  final ValueChanged<PharmacyResult>? onRouteTap;

  /// false — подсказку над меткой не показываем (вместо неё карточка внизу).
  final bool showPopup;

  @override
  Widget build(BuildContext context) {
    final tiles = layer;
    PharmacyResult? highlighted;
    for (final r in results) {
      if (r.pharmacy.id == highlightedId && r.pharmacy.id != routeTargetId) {
        highlighted = r;
      }
    }
    final route = this.route;
    // Ближние падают первыми — волна расходится от пользователя.
    final order = {
      for (var i = 0; i < results.length; i++) results[i].pharmacy.id: i,
    };

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: userPoint,
        initialZoom: 13.5,
        minZoom: 10,
        maxZoom: 18,
        backgroundColor: AppColors.dark
            ? const Color(0xFF0E1110)
            : const Color(0xFFEFF3F1),
        onTap: (_, _) => onMapTap(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          key: ValueKey(tiles),
          urlTemplate: tiles.urlTemplate,
          subdomains: tiles.subdomains,
          userAgentPackageName: 'kg.aptekaryadom.apteka_ryadom',
          // Схему приглушаем, чтобы акцентом были метки.
          // Схему приглушаем, чтобы акцентом были метки; ночную —
          // инвертируем по яркости с сохранением оттенков.
          tileBuilder: tiles == MapLayer.dark
              ? (context, tile, _) => ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_nightMatrix),
                  child: tile,
                )
              : !tiles.muted
              ? null
              : (context, tile, _) => ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.75, 0.15, 0.05, 0, 18, //
                    0.10, 0.80, 0.05, 0, 20, //
                    0.10, 0.15, 0.70, 0, 22, //
                    0, 0, 0, 1, 0,
                  ]),
                  child: tile,
                ),
        ),
        if (route != null && route.points.length > 1)
          _AnimatedRoute(key: ValueKey(route), route: route),
        MarkerLayer(
          markers: [
            for (final r in results)
              Marker(
                key: ValueKey('${r.pharmacy.id}|$animationKey'),
                point: LatLng(r.pharmacy.lat, r.pharmacy.lng),
                width: 56,
                height: 64,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => onMarkerTap(r),
                  child: _AnimatedPin(
                    key: ValueKey('${r.pharmacy.id}|$animationKey'),
                    delay: Duration(
                      milliseconds: 60 * math.min(order[r.pharmacy.id]!, 14),
                    ),
                    selected: r.pharmacy.id == highlightedId,
                    dimmed: !r.isOpen,
                  ),
                ),
              ),
            if (highlighted != null && showPopup)
              Marker(
                key: ValueKey('popup-${highlighted.pharmacy.id}'),
                point: LatLng(
                  highlighted.pharmacy.lat,
                  highlighted.pharmacy.lng,
                ),
                width: 250,
                height: 84,
                alignment: const Alignment(0, -2.5),
                child: _Popup(
                  key: ValueKey('popup-${highlighted.pharmacy.id}'),
                  result: highlighted,
                  onTap: () => onPopupTap(highlighted!),
                  onRoute: onRouteTap == null
                      ? null
                      : () => onRouteTap!(highlighted!),
                ),
              ),
            // Точка «я здесь» — последней: не сдвигает метки аптек
            // (иначе их анимация запускается заново) и рисуется поверх.
            if (showUser || route != null)
              Marker(
                point: userPoint,
                width: 72,
                height: 72,
                child: PulseRing(
                  size: 40,
                  color: AppColors.userDot,
                  child: _UserDot(),
                ),
              ),
          ],
        ),
        SimpleAttributionWidget(
          source: Text(
            tr(context, tiles.attribution),
            style: TextStyle(color: AppColors.textMuted),
          ),
          alignment: Alignment.bottomLeft,
          backgroundColor: Color(0x00000000),
        ),
      ],
    );
  }
}

/// Метка аптеки: падает сверху с переворотом по оси Y и пружинит.
class _AnimatedPin extends StatefulWidget {
  const _AnimatedPin({
    super.key,
    required this.delay,
    required this.selected,
    required this.dimmed,
  });

  final Duration delay;
  final bool selected;
  final bool dimmed;

  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dimmed ? const Color(0xFF9AAEA2) : AppColors.green;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final drop = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: (_c.value * 3).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, -16 * (1 - drop)),
            child: AnimatedScale(
              scale: widget.selected ? 1.3 : 1,
              alignment: Alignment.bottomCenter,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              child: _Pin(color: color, selected: widget.selected),
            ),
          ),
        );
      },
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            // Объём: свет сверху-слева, тень снизу.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.25)!, color],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.55 : 0.3),
                blurRadius: selected ? 18 : 8,
                offset: Offset(0, selected ? 8 : 3),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 24),
        ),
        CustomPaint(size: const Size(12, 8), painter: _TrianglePainter(color)),
        // Тень на «земле» под меткой.
        Container(
          width: selected ? 18 : 12,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: selected ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.userDot,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: cardShadow,
      ),
    );
  }
}

/// Подсказка над выбранной аптекой — раскрывается с 3D-наклоном.
class _Popup extends StatelessWidget {
  const _Popup({
    super.key,
    required this.result,
    required this.onTap,
    this.onRoute,
  });

  final PharmacyResult result;
  final VoidCallback onTap;
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    final price = result.price;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: perspective(0.002)
            ..rotateX(-1.1 * (1 - t))
            ..scaleByDouble(0.7 + 0.3 * t, 0.7 + 0.3 * t, 1, 1),
          child: child,
        ),
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: const Color(0x33000000),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        result.pharmacy.chain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        result.pharmacy.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Text(
                    formatPrice(price),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                if (onRoute != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: tr(context, 'Маршрут'),
                    child: Material(
                      color: AppColors.green,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRoute,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.directions,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Линия маршрута, которая «прорисовывается» от старта к аптеке.
/// Пешком — пунктир, на машине — сплошная.
class _AnimatedRoute extends StatefulWidget {
  const _AnimatedRoute({super.key, required this.route});

  final RouteResult route;

  @override
  State<_AnimatedRoute> createState() => _AnimatedRouteState();
}

class _AnimatedRouteState extends State<_AnimatedRoute>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.route.points;
    final walk = widget.route.mode == TravelMode.walk;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        final count = math.max(2, (all.length * t).ceil());
        final points = all.sublist(0, math.min(count, all.length));
        final transit = widget.route.transit;
        if (transit != null) return _transitLayers(transit, count, t >= 1);
        return PolylineLayer(
          polylines: [
            // Мягкая подложка — линия читается на любой карте.
            Polyline(
              points: points,
              strokeWidth: 12,
              color: AppColors.green.withValues(alpha: 0.18),
            ),
            Polyline(
              points: points,
              strokeWidth: walk ? 6 : 7,
              color: walk ? AppColors.green : AppColors.greenDark,
              borderStrokeWidth: walk ? 0 : 2,
              borderColor: Colors.white,
              pattern: walk
                  ? StrokePattern.dotted(spacingFactor: 1.6)
                  : const StrokePattern.solid(),
            ),
          ],
        );
      },
    );
  }

  /// Как в 2ГИС: пешком — серый пунктир, поездка — синяя линия,
  /// на остановках — подписи с номерами.
  Widget _transitLayers(TransitOption option, int count, bool done) {
    final lines = <Polyline>[];
    var left = count;
    for (final leg in option.legs) {
      if (left <= 0 || leg.points.length < 2) continue;
      final pts = leg.points.sublist(0, math.min(left, leg.points.length));
      left -= leg.points.length;
      if (pts.length < 2) continue;
      if (leg.walk) {
        lines.add(
          Polyline(
            points: pts,
            strokeWidth: 5,
            color: const Color(0xFF6B7570),
            pattern: StrokePattern.dotted(spacingFactor: 1.8),
          ),
        );
      } else {
        lines.add(
          Polyline(
            points: pts,
            strokeWidth: 7,
            color: transitColor(leg.kind),
            borderStrokeWidth: 2,
            borderColor: Colors.white,
          ),
        );
      }
    }
    final labels = <Marker>[];
    final stops = <CircleMarker>[];
    final legs = option.legs;
    if (done) {
      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        if (leg.walk || leg.points.isEmpty) continue;
        final color = transitColor(leg.kind);
        for (final p in [leg.points.first, leg.points.last]) {
          stops.add(
            CircleMarker(
              point: p,
              radius: 6,
              color: Colors.white,
              borderColor: color,
              borderStrokeWidth: 3,
            ),
          );
        }
        labels.add(
          _label(
            leg.points.first,
            icon: transitIcon(leg.kind),
            color: color,
            title: leg.fromStop ?? leg.kindLabel,
            chips: lineChips(leg, max: 3),
          ),
        );
        final after = i + 1 < legs.length ? legs[i + 1] : null;
        if (leg.toStop != null) {
          labels.add(
            _label(
              leg.points.last,
              icon: Icons.directions_walk_rounded,
              color: const Color(0xFF6B7570),
              title: leg.toStop!,
              subtitle: after != null && after.walk && after.distance >= 15
                  ? trNow('Пешком {t}', {'t': formatDuration(after.movingSeconds)})
                  : trNow('Выход'),
            ),
          );
        }
      }
    }
    return Stack(
      children: [
        PolylineLayer(polylines: lines),
        if (stops.isNotEmpty) CircleLayer(circles: stops),
        if (labels.isNotEmpty) MarkerLayer(markers: labels),
      ],
    );
  }

  Marker _label(
    LatLng point, {
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    List<Widget> chips = const [],
  }) {
    return Marker(
      point: point,
      width: 220,
      height: 74,
      alignment: Alignment.topCenter,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 210),
            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      if (chips.isNotEmpty || subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final c in chips) ...[
                                Transform.scale(scale: 0.85, child: c),
                                const SizedBox(width: 1),
                              ],
                              if (subtitle != null)
                                Flexible(
                                  child: Text(
                                    chips.isEmpty ? subtitle : ' $subtitle',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
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
