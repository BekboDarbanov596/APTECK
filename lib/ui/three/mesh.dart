import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

/// Треугольная 3D-сетка: позиции, нормали и базовый цвет каждой вершины.
class Mesh {
  Mesh._(this.positions, this.normals, this.colors, this.indices);

  /// x, y, z подряд. Ось y — вверх, z — к зрителю. Размер ~ [-1, 1].
  final Float32List positions;
  final Float32List normals;

  /// ARGB каждой вершины.
  final Int32List colors;
  final Uint16List indices;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

class _Builder {
  final _p = <double>[];
  final _c = <int>[];
  final _i = <int>[];

  int vertex(double x, double y, double z, Color color) {
    _p
      ..add(x)
      ..add(y)
      ..add(z);
    _c.add(color.toARGB32());
    return _c.length - 1;
  }

  void tri(int a, int b, int c) => _i
    ..add(a)
    ..add(b)
    ..add(c);

  /// Нормали — среднее нормалей соседних граней, направленные наружу
  /// (от центра фигуры), поэтому порядок обхода треугольников не важен.
  Mesh build() {
    final n = _c.length;
    final normals = Float32List(n * 3);
    var cx = 0.0, cy = 0.0, cz = 0.0;
    for (var v = 0; v < n; v++) {
      cx += _p[v * 3];
      cy += _p[v * 3 + 1];
      cz += _p[v * 3 + 2];
    }
    cx /= n;
    cy /= n;
    cz /= n;

    for (var t = 0; t < _i.length; t += 3) {
      final a = _i[t] * 3, b = _i[t + 1] * 3, c = _i[t + 2] * 3;
      final ux = _p[b] - _p[a], uy = _p[b + 1] - _p[a + 1], uz = _p[b + 2] - _p[a + 2];
      final vx = _p[c] - _p[a], vy = _p[c + 1] - _p[a + 1], vz = _p[c + 2] - _p[a + 2];
      var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      // Наружу: от центра к грани.
      final mx = (_p[a] + _p[b] + _p[c]) / 3 - cx;
      final my = (_p[a + 1] + _p[b + 1] + _p[c + 1]) / 3 - cy;
      final mz = (_p[a + 2] + _p[b + 2] + _p[c + 2]) / 3 - cz;
      if (nx * mx + ny * my + nz * mz < 0) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }
      for (final idx in [a, b, c]) {
        normals[idx] += nx;
        normals[idx + 1] += ny;
        normals[idx + 2] += nz;
      }
    }
    for (var v = 0; v < n; v++) {
      final x = normals[v * 3], y = normals[v * 3 + 1], z = normals[v * 3 + 2];
      final len = math.sqrt(x * x + y * y + z * z);
      if (len > 0) {
        normals[v * 3] = x / len;
        normals[v * 3 + 1] = y / len;
        normals[v * 3 + 2] = z / len;
      }
    }
    return Mesh._(
      Float32List.fromList(_p),
      normals,
      Int32List.fromList(_c),
      Uint16List.fromList(_i),
    );
  }

  /// Сетка rows × cols, замкнутая по столбцам (как поверхность вращения).
  void grid(int rows, int cols, (double, double, double, Color) Function(int r, int c) at) {
    final base = _c.length;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final (x, y, z, color) = at(r, c);
        vertex(x, y, z, color);
      }
    }
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols; c++) {
        final c2 = (c + 1) % cols;
        final a = base + r * cols + c;
        final b = base + r * cols + c2;
        final d = base + (r + 1) * cols + c;
        final e = base + (r + 1) * cols + c2;
        tri(a, b, d);
        tri(b, e, d);
      }
    }
  }
}

double _spow(double v, double e) => v.sign * math.pow(v.abs(), e).toDouble();

/// Поверхность вращения вокруг оси y по профилю (радиус, высота).
Mesh lathe(List<(double r, double y)> profile, Color Function(double y) colorAt,
    {int segments = 28}) {
  final b = _Builder();
  b.grid(profile.length, segments, (r, c) {
    final a = 2 * math.pi * c / segments;
    final (rad, y) = profile[r];
    return (rad * math.cos(a), y, rad * math.sin(a), colorAt(y));
  });
  return b.build();
}

/// Суперэллипсоид: от таблетки и капсулы до скруглённого бруска.
Mesh superellipsoid({
  required double a,
  required double b,
  required double c,
  required double e1,
  required double e2,
  required Color Function(double x, double y, double z) colorAt,
  int rows = 18,
  int cols = 30,
}) {
  final m = _Builder();
  m.grid(rows, cols, (r, col) {
    final eta = -math.pi / 2 + math.pi * r / (rows - 1);
    final w = -math.pi + 2 * math.pi * col / cols;
    final ce = _spow(math.cos(eta), e1);
    final x = a * ce * _spow(math.cos(w), e2);
    final z = c * ce * _spow(math.sin(w), e2);
    final y = b * _spow(math.sin(eta), e1);
    return (x, y, z, colorAt(x, y, z));
  });
  return m.build();
}

/// Объёмное сердце: контур сердца, «надутый» по оси z.
Mesh heart(Color color, {int rows = 14, int cols = 40}) {
  final m = _Builder();
  m.grid(rows, cols, (r, c) {
    final phi = -math.pi / 2 + math.pi * r / (rows - 1);
    final t = 2 * math.pi * c / cols;
    final hx = 16 * math.pow(math.sin(t), 3) / 17;
    final hy = (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 17;
    final k = math.cos(phi);
    return (hx * k, hy * k + 0.15, 0.42 * math.sin(phi), color);
  });
  return m.build();
}

// ---------------------------------------------------------------------------
// Объекты разделов каталога
// ---------------------------------------------------------------------------

enum Shape3D { tablet, oval, capsule, heart, drop, spray, bottle, bandage }

/// Сетки строятся один раз и переиспользуются.
final _cache = <Shape3D, Mesh>{};

Mesh meshFor(Shape3D shape) => _cache.putIfAbsent(shape, () => _build(shape));

Mesh _build(Shape3D shape) {
  switch (shape) {
    case Shape3D.tablet:
      // Круглая белая таблетка с риской.
      return superellipsoid(
        a: 0.95, b: 0.34, c: 0.95, e1: 0.35, e2: 1,
        colorAt: (x, y, z) => x.abs() < 0.04 && y.abs() > 0.25
            ? const Color(0xFFD4DCD8)
            : const Color(0xFFF7FAF8),
      );
    case Shape3D.oval:
      return superellipsoid(
        a: 1.0, b: 0.36, c: 0.62, e1: 0.45, e2: 1,
        colorAt: (_, _, _) => const Color(0xFFC3A6F2),
      );
    case Shape3D.capsule:
      // Двухцветная капсула.
      return lathe([
        for (var i = 0; i <= 8; i++)
          (0.38 * math.sin(math.pi / 2 * i / 8), -1.0 + 0.38 * (1 - math.cos(math.pi / 2 * i / 8))),
        (0.38, -0.2),
        (0.38, 0.2),
        for (var i = 8; i >= 0; i--)
          (0.38 * math.sin(math.pi / 2 * i / 8), 1.0 - 0.38 * (1 - math.cos(math.pi / 2 * i / 8))),
      ], (y) => y > 0 ? const Color(0xFFE5484D) : const Color(0xFFF6F2EE));
    case Shape3D.heart:
      return heart(const Color(0xFFE5484D));
    case Shape3D.drop:
      // Капля: острая сверху (t = 0), круглая снизу (t = π).
      return lathe([
        for (var i = 0; i <= 18; i++)
          (
            0.8 * math.sin(math.pi * i / 18) * math.sin(math.pi * i / 36),
            0.95 * math.cos(math.pi * i / 18),
          ),
      ], (_) => const Color(0xFF3D9BE9));
    case Shape3D.spray:
      // Назальный спрей: флакон, плечики, носик.
      return lathe([
        (0.0, -1.0),
        (0.40, -1.0),
        (0.46, -0.94),
        (0.46, 0.25),
        (0.36, 0.38),
        (0.18, 0.46),
        (0.18, 0.56),
        (0.11, 0.62),
        (0.09, 1.0),
        (0.0, 1.02),
      ], (y) => y > 0.42 ? const Color(0xFFF7FAF8) : const Color(0xFF7FC1EE));
    case Shape3D.bottle:
      // Флакон сиропа с белой крышкой.
      return lathe([
        (0.0, -1.0),
        (0.50, -1.0),
        (0.56, -0.92),
        (0.56, 0.20),
        (0.40, 0.42),
        (0.22, 0.52),
        (0.24, 0.56),
        (0.24, 0.92),
        (0.20, 0.98),
        (0.0, 0.98),
      ], (y) => y > 0.54 ? const Color(0xFFF7FAF8) : const Color(0xFFD48A2C));
    case Shape3D.bandage:
      // Пластырь с подушечкой посередине.
      return superellipsoid(
        a: 1.15, b: 0.12, c: 0.42, e1: 0.4, e2: 0.35,
        colorAt: (x, _, _) => x.abs() < 0.38 ? const Color(0xFFFAF1E6) : const Color(0xFFE6C29B),
      );
  }
}
