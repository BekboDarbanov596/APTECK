import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

class RouteTraceArt extends StatelessWidget {
  const RouteTraceArt({super.key, required this.points, required this.accent});

  final List<LatLng> points;
  final Color accent;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: TweenAnimationBuilder<double>(
      key: ObjectKey(points),
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) =>
          CustomPaint(painter: _RouteTracePainter(points, accent, progress)),
    ),
  );
}

class _RouteTracePainter extends CustomPainter {
  const _RouteTracePainter(this.points, this.accent, this.progress);

  final List<LatLng> points;
  final Color accent;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 24 || size.height <= 24) return;

    final grid = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (var x = 9.0; x < size.width; x += 10) {
      for (var y = 9.0; y < size.height; y += 10) {
        canvas.drawCircle(Offset(x, y), 0.65, grid);
      }
    }

    final origin = points.first;
    final longitudeScale = math.cos(origin.latitude * math.pi / 180);
    final projected = [
      for (final point in points)
        Offset(
          (point.longitude - origin.longitude) * longitudeScale,
          origin.latitude - point.latitude,
        ),
    ];
    var minX = 0.0, minY = 0.0, maxX = 0.0, maxY = 0.0;
    for (final point in projected) {
      minX = math.min(minX, point.dx);
      minY = math.min(minY, point.dy);
      maxX = math.max(maxX, point.dx);
      maxY = math.max(maxY, point.dy);
    }
    final spanX = maxX - minX, spanY = maxY - minY;
    if (spanX == 0 && spanY == 0) return;
    final scale = math.min(
      (size.width - 28) / math.max(spanX, 1e-12),
      (size.height - 30) / math.max(spanY, 1e-12),
    );
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    Offset position(Offset point) =>
        size.center(Offset.zero) + (point - center) * scale;

    final start = position(projected.first);
    final end = position(projected.last);
    final path = Path()..moveTo(start.dx, start.dy);
    for (final point in projected.skip(1)) {
      final next = position(point);
      path.lineTo(next.dx, next.dy);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      path,
      stroke
        ..color = accent.withValues(alpha: 0.22)
        ..strokeWidth = 3,
    );
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        stroke
          ..color = accent
          ..strokeWidth = 3,
      );
    }
    canvas.drawCircle(start, 4, Paint()..color = const Color(0xFF162D45));
    canvas.drawCircle(
      start,
      3,
      stroke
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(end, 7, Paint()..color = accent.withValues(alpha: 0.23));
    canvas.drawCircle(end, 4, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_RouteTracePainter old) =>
      old.points != points || old.accent != accent || old.progress != progress;
}
