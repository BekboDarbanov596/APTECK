import 'dart:math' as math;

import '../l10n/lang.dart';

/// Площадь Ала-Тоо — точка по умолчанию, если геолокация недоступна.
const bishkekCenterLat = 42.8766;
const bishkekCenterLng = 74.6036;

/// Расстояние между двумя точками в метрах (формула гаверсинусов).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

double _rad(double deg) => deg * math.pi / 180;

/// «450 м», «1,2 км», «12 км».
String formatDistance(double meters) {
  final en = currentLang == AppLang.en;
  final m = en ? 'm' : 'м', kmUnit = en ? 'km' : 'км';
  if (meters < 1000) {
    final rounded = (meters / 10).round() * 10;
    return '${rounded < 10 ? 10 : rounded} $m';
  }
  final km = meters / 1000;
  if (km < 10) {
    final v = km.toStringAsFixed(1);
    return '${en ? v : v.replaceAll('.', ',')} $kmUnit';
  }
  return '${km.round()} $kmUnit';
}
