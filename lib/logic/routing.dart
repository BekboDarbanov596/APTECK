import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

/// Как добираемся. Профили открытого сервера маршрутов OSRM (FOSSGIS).
enum TravelMode {
  walk('routed-foot', 'Пешком'),
  car('routed-car', 'На машине');

  const TravelMode(this.profile, this.label);
  final String profile;
  final String label;
}

/// Один шаг маршрута: «Поверните направо на ул. Киевская» и сколько идти.
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distance,
    required this.kind,
  });

  final String instruction;
  final double distance;

  /// Для иконки: left, right, straight, uturn, arrive, depart, roundabout.
  final String kind;
}

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
    required this.mode,
  });

  final List<LatLng> points;

  /// Метры и секунды.
  final double distance;
  final double duration;
  final List<RouteStep> steps;
  final TravelMode mode;
}

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Построение маршрута по улицам через открытый сервер OSRM
/// (routing.openstreetmap.de, данные OpenStreetMap, без ключа).
class RouteService {
  RouteService({
    http.Client? client,
    this.baseUrl = 'https://routing.openstreetmap.de',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<RouteResult> route(LatLng from, LatLng to, TravelMode mode) async {
    // В пути OSRM всегда пишется «driving», профиль задаёт адрес сервера.
    final uri = Uri.parse(
      '$baseUrl/${mode.profile}/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const RoutingException(
        'Сервер маршрутов не ответил. Попробуйте ещё раз.',
      );
    } catch (_) {
      throw const RoutingException(
        'Нет интернета — маршрут построить не удалось.',
      );
    }
    if (res.statusCode == 429) {
      throw const RoutingException('Слишком много запросов. Подождите минуту.');
    }
    if (res.statusCode != 200) {
      throw RoutingException(
        'Сервер маршрутов вернул ошибку ${res.statusCode}.',
      );
    }
    return parseOsrmResponse(utf8.decode(res.bodyBytes), mode);
  }
}

/// Разбор ответа OSRM. Отдельной функцией — чтобы проверить тестами.
RouteResult parseOsrmResponse(String body, TravelMode mode) {
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    throw const RoutingException(
      'Не удалось прочитать ответ сервера маршрутов.',
    );
  }
  if (json['code'] != 'Ok') {
    throw RoutingException(
      json['code'] == 'NoRoute'
          ? 'Между этими точками нет маршрута.'
          : 'Не удалось построить маршрут.',
    );
  }
  final routes = json['routes'] as List? ?? const [];
  if (routes.isEmpty)
    throw const RoutingException('Не удалось построить маршрут.');
  final route = routes.first as Map<String, dynamic>;

  final coords =
      (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
  final points = [
    for (final c in coords)
      LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
  ];

  final steps = <RouteStep>[];
  for (final leg in route['legs'] as List? ?? const []) {
    for (final s
        in (leg as Map<String, dynamic>)['steps'] as List? ?? const []) {
      final step = s as Map<String, dynamic>;
      final m = step['maneuver'] as Map<String, dynamic>;
      steps.add(
        RouteStep(
          instruction: instructionRu(
            type: m['type'] as String? ?? '',
            modifier: m['modifier'] as String?,
            name: step['name'] as String? ?? '',
            exit: m['exit'] as int?,
          ),
          distance: (step['distance'] as num?)?.toDouble() ?? 0,
          kind: stepKind(m['type'] as String? ?? '', m['modifier'] as String?),
        ),
      );
    }
  }

  return RouteResult(
    points: points,
    distance: (route['distance'] as num).toDouble(),
    duration: (route['duration'] as num).toDouble(),
    steps: steps,
    mode: mode,
  );
}

/// Подсказка по-русски из типа манёвра OSRM.
String instructionRu({
  required String type,
  String? modifier,
  String name = '',
  int? exit,
}) {
  final onto = name.isEmpty ? '' : ' на $name';
  final along = name.isEmpty ? '' : ' по $name';
  final dir = switch (modifier) {
    'left' => 'налево',
    'right' => 'направо',
    'slight left' => 'плавно налево',
    'slight right' => 'плавно направо',
    'sharp left' => 'резко налево',
    'sharp right' => 'резко направо',
    'uturn' => 'и развернитесь',
    _ => 'прямо',
  };
  return switch (type) {
    'depart' => 'Начните движение$along',
    'arrive' => 'Вы на месте — аптека ${_side(modifier)}',
    'roundabout' || 'rotary' || 'roundabout turn' =>
      exit == null
          ? 'Проезжайте круговое движение$onto'
          : 'На круге — $exit-й съезд$onto',
    'continue' || 'new name' =>
      modifier == null || modifier == 'straight'
          ? 'Продолжайте прямо$along'
          : 'Держитесь $dir$onto',
    'fork' => 'На развилке держитесь $dir$onto',
    'merge' => 'Перестройтесь $dir$onto',
    'end of road' => 'В конце дороги поверните $dir$onto',
    'on ramp' || 'off ramp' => 'Съезд $dir$onto',
    _ =>
      modifier == 'uturn'
          ? 'Развернитесь$onto'
          : modifier == null || modifier == 'straight'
          ? 'Идите прямо$along'
          : 'Поверните $dir$onto',
  };
}

String _side(String? modifier) => switch (modifier) {
  'left' || 'slight left' || 'sharp left' => 'слева',
  'right' || 'slight right' || 'sharp right' => 'справа',
  _ => 'впереди',
};

String stepKind(String type, String? modifier) {
  if (type == 'depart') return 'depart';
  if (type == 'arrive') return 'arrive';
  if (type.contains('roundabout') || type == 'rotary') return 'roundabout';
  if (modifier == 'uturn') return 'uturn';
  if (modifier?.contains('left') ?? false) return 'left';
  if (modifier?.contains('right') ?? false) return 'right';
  return 'straight';
}

/// «7 мин», «1 ч 05 мин», «меньше минуты».
String formatDuration(double seconds) {
  final min = (seconds / 60).round();
  if (min < 1) return 'меньше минуты';
  if (min < 60) return '$min мин';
  return '${min ~/ 60} ч ${(min % 60).toString().padLeft(2, '0')} мин';
}
