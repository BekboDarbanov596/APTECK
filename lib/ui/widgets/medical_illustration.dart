import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Спокойная медицинская графика: единая толщина линий и реальные детали.
class MedicalIllustration extends StatelessWidget {
  const MedicalIllustration({
    super.key,
    required this.category,
    this.size = 96,
    this.light = false,
  });
  final String category;
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MedicalPainter(category, light)),
  );
}

class _MedicalPainter extends CustomPainter {
  const _MedicalPainter(this.category, this.light);
  final String category;
  final bool light;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final ink = light ? const Color(0xFFE0F2EC) : const Color(0xFF365E59);
    final stroke = Paint()
      ..color = ink
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = ink.withValues(alpha: 0.055);
    void path(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }

    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), stroke);
    void round(Rect r, double radius) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)),
        stroke,
      );
    }

    switch (category) {
      case 'Боль и температура':
        path(
          Path()
            ..moveTo(42, 60)
            ..lineTo(42, 25)
            ..cubicTo(42, 13, 58, 13, 58, 25)
            ..lineTo(58, 60)
            ..cubicTo(77, 75, 63, 94, 50, 90)
            ..cubicTo(34, 90, 26, 73, 42, 60)
            ..close(),
        );
        line(50, 35, 50, 72);
        canvas.drawCircle(
          const Offset(50, 76),
          5,
          Paint()..color = ink.withValues(alpha: 0.65),
        );
        for (var i = 0; i < 5; i++) {
          line(58, 29 + i * 6, 64, 29 + i * 6);
        }
      case 'Аллергия':
        path(
          Path()
            ..moveTo(50, 81)
            ..cubicTo(46, 62, 51, 45, 68, 23)
            ..cubicTo(83, 43, 81, 66, 50, 70),
        );
        path(
          Path()
            ..moveTo(49, 63)
            ..cubicTo(27, 66, 19, 44, 25, 29)
            ..cubicTo(44, 34, 51, 42, 49, 63),
        );
        line(51, 67, 68, 35);
        line(47, 58, 31, 39);
        for (final point in [
          const Offset(28, 76),
          const Offset(77, 72),
          const Offset(37, 20),
        ]) {
          canvas.drawCircle(point, 2, stroke);
        }
      case 'Антибиотики':
        canvas.save();
        canvas.translate(50, 51);
        canvas.rotate(0.62);
        round(const Rect.fromLTWH(-15, -36, 30, 72), 15);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-11, -31, 22, 29),
            const Radius.circular(10),
          ),
          Paint()..color = ink.withValues(alpha: 0.12),
        );
        line(-15, 0, 15, 0);
        for (var i = 0; i < 3; i++) {
          line(-6 + i * 6, 12, -6 + i * 6, 20);
        }
        canvas.restore();
      case 'Желудок и кишечник':
        path(
          Path()
            ..moveTo(49, 15)
            ..lineTo(49, 35)
            ..cubicTo(49, 48, 70, 22, 79, 41)
            ..cubicTo(94, 73, 61, 91, 43, 79)
            ..cubicTo(33, 72, 29, 61, 21, 67)
            ..lineTo(18, 59)
            ..cubicTo(31, 49, 44, 67, 46, 60)
            ..cubicTo(49, 54, 38, 48, 38, 35)
            ..lineTo(38, 15),
        );
        canvas.drawPath(
          Path()
            ..moveTo(66, 45)
            ..cubicTo(79, 57, 65, 74, 55, 72),
          stroke,
        );
      case 'Сердце и давление':
        path(
          Path()
            ..moveTo(50, 82)
            ..cubicTo(32, 70, 12, 51, 20, 32)
            ..cubicTo(27, 14, 44, 19, 50, 30)
            ..cubicTo(60, 13, 78, 18, 82, 34)
            ..cubicTo(88, 54, 65, 73, 50, 82)
            ..close(),
        );
        canvas.drawPath(
          Path()
            ..moveTo(17, 51)
            ..lineTo(36, 51)
            ..lineTo(43, 40)
            ..lineTo(52, 64)
            ..lineTo(60, 47)
            ..lineTo(65, 51)
            ..lineTo(84, 51),
          stroke,
        );
      case 'Диабет':
        round(const Rect.fromLTWH(27, 27, 47, 62), 10);
        round(const Rect.fromLTWH(36, 39, 29, 20), 3);
        round(const Rect.fromLTWH(45, 10, 12, 17), 2);
        canvas.drawCircle(const Offset(50, 74), 4, stroke);
        line(43, 49, 47, 49);
        line(53, 49, 58, 49);
      case 'Простуда и нос':
        round(const Rect.fromLTWH(31, 42, 39, 46), 8);
        round(const Rect.fromLTWH(40, 31, 21, 11), 2);
        path(
          Path()
            ..moveTo(43, 31)
            ..lineTo(43, 22)
            ..lineTo(63, 22)
            ..lineTo(63, 16)
            ..lineTo(36, 16)
            ..lineTo(36, 22)
            ..lineTo(43, 22),
        );
        line(44, 62, 57, 62);
        line(50.5, 55.5, 50.5, 68.5);
        for (var i = 0; i < 3; i++) {
          line(72, 16 + i * 5, 78 + i * 2, 13 + i * 7);
        }
      default:
        canvas.save();
        canvas.translate(50, 50);
        canvas.rotate(-math.pi / 4);
        round(const Rect.fromLTWH(-16, -37, 32, 74), 15);
        round(const Rect.fromLTWH(-10, -12, 20, 24), 4);
        for (final y in [-24.0, 24.0]) {
          for (final x in [-5.0, 5.0]) {
            canvas.drawCircle(Offset(x, y), 1, Paint()..color = ink);
          }
        }
        canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MedicalPainter old) =>
      old.category != category || old.light != light;
}
