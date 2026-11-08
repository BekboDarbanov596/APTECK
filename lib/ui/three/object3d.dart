import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'mesh.dart';

/// Управление объектом снаружи: например, сделать оборот по нажатию.
class Object3DController extends ChangeNotifier {
  void spin() => notifyListeners();
}

/// Настоящий 3D-объект: сетка треугольников, перспектива, свет с бликом
/// и мягкая тень. Медленно вращается и «парит».
class Object3D extends StatefulWidget {
  const Object3D({
    super.key,
    required this.shape,
    this.size = 96,
    this.controller,
    this.tilt = 0.45,
    this.period = const Duration(seconds: 9),
    this.phase = 0,
  });

  final Shape3D shape;
  final double size;
  final Object3DController? controller;

  /// Наклон к зрителю (радианы), чтобы был виден объём.
  final double tilt;
  final Duration period;

  /// Сдвиг фазы — чтобы соседние объекты не крутились синхронно.
  final double phase;

  @override
  State<Object3D> createState() => _Object3DState();
}

class _Object3DState extends State<Object3D> with TickerProviderStateMixin {
  late final _idle = AnimationController(vsync: this, duration: widget.period);
  late final _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onSpin);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Если в системе отключены анимации — объект стоит неподвижно.
    if (MediaQuery.disableAnimationsOf(context)) {
      _idle.stop();
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  @override
  void didUpdateWidget(Object3D old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onSpin);
      widget.controller?.addListener(_onSpin);
    }
  }

  void _onSpin() => _burst.forward(from: 0);

  @override
  void dispose() {
    widget.controller?.removeListener(_onSpin);
    _idle.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesh = meshFor(widget.shape);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _burst]),
        builder: (context, _) {
          final t = _idle.value + widget.phase;
          final b = Curves.easeOutBack.transform(_burst.value);
          final jump = math.sin(math.pi * _burst.value);
          // Плоские фигуры (сердце) сбоку теряют форму — их покачиваем, а не крутим.
          final flat = widget.shape == Shape3D.heart;
          final idleY =
              (flat ? -0.12 : -0.32) + 0.22 * math.sin(2 * math.pi * t);
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _MeshPainter(
              mesh: mesh,
              rotY: idleY + 2 * math.pi * b,
              rotX:
                  (flat ? 0.12 : widget.tilt) +
                  0.12 * math.sin(2 * math.pi * t * 2),
              rotZ: -0.16 + 0.08 * math.sin(2 * math.pi * t),
              lift: 0.06 * math.sin(2 * math.pi * t * 2) + 0.18 * jump,
              scale: 1 + 0.12 * jump,
            ),
          );
        },
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.mesh,
    required this.rotY,
    required this.rotX,
    required this.rotZ,
    required this.lift,
    required this.scale,
  });

  final Mesh mesh;
  final double rotY, rotX, rotZ, lift, scale;

  // Свет сверху-слева-спереди; полувектор для блика.
  static const _lx = -0.45, _ly = 0.65, _lz = 0.62;
  static final _hLen = math.sqrt(
    _lx * _lx + (_ly) * (_ly) + (_lz + 1) * (_lz + 1),
  );
  static final _hx = _lx / _hLen, _hy = _ly / _hLen, _hz = (_lz + 1) / _hLen;

  @override
  void paint(Canvas canvas, Size size) {
    final n = mesh.vertexCount;
    final half = size.width / 2;
    final unit = size.width * 0.4 * scale;

    // Тень на «полу»: тем меньше и прозрачнее, чем выше объект.
    final shadowW = size.width * (0.62 - lift * 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(half, size.height * 0.86),
        width: shadowW,
        height: shadowW * 0.18,
      ),
      Paint()
        ..color = Colors.black.withValues(
          alpha: (0.16 - lift * 0.15).clamp(0.04, 0.2),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Матрица поворота: сначала Y (вращение), потом X (наклон), потом Z (покачивание).
    final cy = math.cos(rotY), sy = math.sin(rotY);
    final cx = math.cos(rotX), sx = math.sin(rotX);
    final cz = math.cos(rotZ), sz = math.sin(rotZ);

    final px = Float32List(n), py = Float32List(n), pz = Float32List(n);
    final colors = Int32List(n);
    final p = mesh.positions, nr = mesh.normals;

    for (var i = 0; i < n; i++) {
      // Позиция
      var x = p[i * 3], y = p[i * 3 + 1], z = p[i * 3 + 2];
      var x1 = x * cy + z * sy, z1 = -x * sy + z * cy;
      var y2 = y * cx - z1 * sx, z2 = y * sx + z1 * cx;
      var x3 = x1 * cz - y2 * sz, y3 = x1 * sz + y2 * cz;
      pz[i] = z2;
      final persp = 4.2 / (4.2 - z2);
      px[i] = half + x3 * unit * persp;
      py[i] = size.height * 0.44 - (y3 + lift) * unit * persp;

      // Нормаль
      x = nr[i * 3];
      y = nr[i * 3 + 1];
      z = nr[i * 3 + 2];
      x1 = x * cy + z * sy;
      z1 = -x * sy + z * cy;
      y2 = y * cx - z1 * sx;
      z2 = y * sx + z1 * cx;
      x3 = x1 * cz - y2 * sz;
      y3 = x1 * sz + y2 * cz;

      // Освещение: рассеянный + диффузный + блик + контровой свет по краю.
      final diffuse = math.max(0.0, x3 * _lx + y3 * _ly + z2 * _lz);
      final spec = math
          .pow(math.max(0.0, x3 * _hx + y3 * _hy + z2 * _hz), 36)
          .toDouble();
      final rim = math.pow(1 - z2.abs().clamp(0.0, 1.0), 3).toDouble() * 0.18;
      final light = 0.50 + 0.56 * diffuse;

      final base = mesh.colors[i];
      int ch(int shift) {
        final c = (base >> shift) & 0xFF;
        return (c * light + 255 * (0.55 * spec + rim)).round().clamp(0, 255);
      }

      colors[i] = 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
    }

    // Сортировка треугольников от дальних к ближним (алгоритм художника).
    final idx = mesh.indices;
    final triCount = mesh.triangleCount;
    final order = List<int>.generate(triCount, (t) => t);
    final depth = Float32List(triCount);
    for (var t = 0; t < triCount; t++) {
      depth[t] = pz[idx[t * 3]] + pz[idx[t * 3 + 1]] + pz[idx[t * 3 + 2]];
    }
    order.sort((a, b) => depth[a].compareTo(depth[b]));

    final positions = Float32List(triCount * 6);
    final vColors = Int32List(triCount * 3);
    var k = 0;
    for (final t in order) {
      for (var j = 0; j < 3; j++) {
        final v = idx[t * 3 + j];
        positions[k * 2] = px[v];
        positions[k * 2 + 1] = py[v];
        vColors[k] = colors[v];
        k++;
      }
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: vColors,
    );
    canvas.drawVertices(vertices, BlendMode.dst, Paint()..isAntiAlias = true);
    vertices.dispose();
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.rotY != rotY ||
      old.rotX != rotX ||
      old.rotZ != rotZ ||
      old.lift != lift ||
      old.scale != scale ||
      old.mesh != mesh;
}

/// Какой объект показывать для раздела каталога.
Shape3D shapeForCategory(String category) => switch (category) {
  'Боль и температура' => Shape3D.tablet,
  'Простуда и нос' => Shape3D.spray,
  'Аллергия' => Shape3D.oval,
  'Желудок и кишечник' => Shape3D.bottle,
  'Сердце и давление' => Shape3D.heart,
  'Антибиотики' => Shape3D.capsule,
  'Диабет' => Shape3D.drop,
  'Кожа и раны' => Shape3D.bandage,
  _ => Shape3D.tablet,
};
