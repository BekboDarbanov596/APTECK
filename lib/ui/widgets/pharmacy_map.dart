import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../state/app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'motion.dart';

/// Карта на весь экран: аптеки «падают» на карту с 3D-переворотом,
/// выбранная поднимается, над ней всплывает подсказка с ценой.
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

  @override
  Widget build(BuildContext context) {
    PharmacyResult? highlighted;
    for (final r in results) {
      if (r.pharmacy.id == highlightedId) highlighted = r;
    }
    // Ближние падают первыми — волна расходится от пользователя.
    final order = {for (var i = 0; i < results.length; i++) results[i].pharmacy.id: i};

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: userPoint,
        initialZoom: 13.5,
        minZoom: 10,
        maxZoom: 18,
        backgroundColor: const Color(0xFFEFF3F1),
        onTap: (_, _) => onMapTap(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'kg.aptekaryadom.apteka_ryadom',
          // Приглушаем карту, чтобы акцентом были метки.
          tileBuilder: (context, tile, _) => ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.75, 0.15, 0.05, 0, 18, //
              0.10, 0.80, 0.05, 0, 20, //
              0.10, 0.15, 0.70, 0, 22, //
              0, 0, 0, 1, 0,
            ]),
            child: tile,
          ),
        ),
        MarkerLayer(
          markers: [
            if (showUser)
              Marker(
                point: userPoint,
                width: 72,
                height: 72,
                child: const PulseRing(
                  size: 40,
                  color: AppColors.userDot,
                  child: _UserDot(),
                ),
              ),
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
                    delay: Duration(milliseconds: 60 * math.min(order[r.pharmacy.id]!, 14)),
                    selected: r.pharmacy.id == highlightedId,
                    dimmed: !r.isOpen,
                  ),
                ),
              ),
            if (highlighted != null)
              Marker(
                key: ValueKey('popup-${highlighted.pharmacy.id}'),
                point: LatLng(highlighted.pharmacy.lat, highlighted.pharmacy.lng),
                width: 230,
                height: 84,
                alignment: const Alignment(0, -2.5),
                child: _Popup(
                  key: ValueKey('popup-${highlighted.pharmacy.id}'),
                  result: highlighted,
                  onTap: () => onPopupTap(highlighted!),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('участники OpenStreetMap'),
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

class _AnimatedPinState extends State<_AnimatedPin> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

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
        final drop = Curves.elasticOut.transform(_c.value);
        final flip = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: (_c.value * 3).clamp(0, 1),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: perspective(0.004)
              ..translateByDouble(0, -60 * (1 - drop), 0, 1)
              ..rotateY(math.pi * (1 - flip)),
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
  const _Popup({super.key, required this.result, required this.onTap});

  final PharmacyResult result;
  final VoidCallback onTap;

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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        result.pharmacy.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Text(
                    formatPrice(price),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
