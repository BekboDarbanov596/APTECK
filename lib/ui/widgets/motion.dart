import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Матрица с перспективой — без неё повороты по осям X/Y выглядят плоско.
Matrix4 perspective([double depth = 0.0015]) => Matrix4.identity()..setEntry(3, 2, depth);

/// Появление с 3D-переворотом: элемент «встаёт» из наклона по оси X.
class FlipIn extends StatefulWidget {
  const FlipIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.fromAngle = 0.9,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Начальный наклон в радианах.
  final double fromAngle;

  @override
  State<FlipIn> createState() => _FlipInState();
}

class _FlipInState extends State<FlipIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  late final _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform(
            alignment: Alignment.topCenter,
            transform: perspective()
              ..translateByDouble(0, 24 * (1 - t), 0, 1)
              ..rotateX(widget.fromAngle * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Объёмный отклик на нажатие: карточка слегка «проваливается» и наклоняется.
class PressTilt extends StatefulWidget {
  const PressTilt({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<PressTilt> createState() => _PressTiltState();
}

class _PressTiltState extends State<PressTilt> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _down ? 1 : 0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: widget.child,
        builder: (context, v, child) => Transform(
          alignment: Alignment.center,
          transform: perspective(0.002)
            ..rotateX(0.12 * v)
            ..scaleByDouble(1 - 0.03 * v, 1 - 0.03 * v, 1, 1),
          child: child,
        ),
      ),
    );
  }
}

/// Бесконечно расходящиеся кольца — «дыхание» кнопки или точки.
class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.child,
    required this.color,
    this.size = 56,
    this.period = const Duration(milliseconds: 2200),
  });

  final Widget child;
  final Color color;
  final double size;
  final Duration period;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size * 1.8,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            for (final shift in const [0.0, 0.5])
              Builder(builder: (_) {
                final t = (_c.value + shift) % 1;
                return Container(
                  width: widget.size * (1 + 0.8 * t),
                  height: widget.size * (1 + 0.8 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.28 * (1 - t)),
                  ),
                );
              }),
            child!,
          ],
        ),
      ),
    );
  }
}

/// Вращение по оси Y — объёмный логотип. [turns] = null — бесконечно.
class Spin3D extends StatefulWidget {
  const Spin3D({
    super.key,
    required this.child,
    this.turns = 1,
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final int? turns;
  final Duration duration;

  @override
  State<Spin3D> createState() => _Spin3DState();
}

class _Spin3DState extends State<Spin3D> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.turns == null) {
      _c.repeat();
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = widget.turns == null ? Curves.linear : Curves.easeInOutCubic;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => Transform(
        alignment: Alignment.center,
        transform: perspective(0.003)
          ..rotateY(2 * math.pi * (widget.turns ?? 1) * curve.transform(_c.value)),
        child: child,
      ),
    );
  }
}

/// Плавный «перелёт» камеры карты: по дуге с отдалением посередине пути.
class MapFlyer {
  MapFlyer(this.controller, TickerProvider vsync)
      : _anim = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 900));

  final MapController controller;
  final AnimationController _anim;
  VoidCallback? _listener;

  void flyTo(LatLng target, double zoom) {
    final from = controller.camera;
    final start = from.center;
    final startZoom = from.zoom;
    final distance = (start.latitude - target.latitude).abs() +
        (start.longitude - target.longitude).abs();
    // Чем дальше лететь, тем сильнее «подъём» камеры.
    final lift = (distance * 30).clamp(0.0, 1.2);
    final curve = Curves.easeInOutCubic;

    if (_listener != null) _anim.removeListener(_listener!);
    _listener = () {
      final t = curve.transform(_anim.value);
      final lat = start.latitude + (target.latitude - start.latitude) * t;
      final lng = start.longitude + (target.longitude - start.longitude) * t;
      final z = startZoom + (zoom - startZoom) * t - lift * math.sin(math.pi * t);
      controller.move(LatLng(lat, lng), z);
    };
    _anim
      ..addListener(_listener!)
      ..forward(from: 0);
  }

  /// Перелёт так, чтобы все точки попали в кадр.
  void flyToFit(CameraFit fit) {
    final target = fit.fit(controller.camera);
    flyTo(target.center, target.zoom);
  }

  void dispose() => _anim.dispose();
}
