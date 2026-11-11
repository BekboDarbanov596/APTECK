import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

/// Маршрут общественным транспортом из API 2ГИС (`/public_transport/2.0`):
/// реальные номера автобусов, троллейбусов и маршруток Бишкека, остановки,
/// пересадки и время с учётом расписания.
/// Документация: https://docs.2gis.com/en/api/navigation/routing/start
///
/// Нужен ключ 2ГИС (демо-ключ — в Platform Manager). Ключ не хранится в коде:
/// при сборке `--dart-define=TWOGIS_KEY=...`.

/// Один участок: пешком или на конкретном маршруте.
class TransitLeg {
  const TransitLeg({
    required this.walk,
    required this.distance,
    required this.movingSeconds,
    required this.waitingSeconds,
    required this.points,
    this.lines = const [],
    this.kind,
    this.fromStop,
    this.toStop,
    this.stopCount = 0,
  });

  final bool walk;

  /// Номера маршрутов на этом участке: «10», «212» (подойдёт любой из них).
  final List<String> lines;

  /// bus, trolleybus, shuttle_bus (маршрутка), tram…
  final String? kind;

  /// Остановка посадки.
  final String? fromStop;

  /// Остановка выхода.
  final String? toStop;

  /// Сколько остановок проехать (включая остановку выхода).
  final int stopCount;
  final double distance;
  final double movingSeconds;
  final double waitingSeconds;
  final List<LatLng> points;

  /// «Автобус», «Маршрутка»… — для подписи.
  String get kindLabel => switch (kind) {
    'trolleybus' => 'Троллейбус',
    'shuttle_bus' => 'Маршрутка',
    'tram' => 'Трамвай',
    'metro' => 'Метро',
    _ => 'Автобус',
  };
}

/// Один вариант поездки.
class TransitOption {
  const TransitOption({
    required this.legs,
    required this.totalSeconds,
    required this.totalDistance,
    required this.transfers,
    this.departure,
    this.intervalMinutes,
    this.arrival,
  });

  final List<TransitLeg> legs;
  final double totalSeconds;
  final double totalDistance;

  /// Пересадок между маршрутами.
  final int transfers;

  /// Ближайшее отправление по расписанию: «11:36».
  final String? departure;

  /// Интервал движения, мин — в Бишкеке 2ГИС обычно даёт его вместо точного времени.
  final int? intervalMinutes;

  /// Время прибытия по 2ГИС («Вы на месте в 16:00.» → «16:00»).
  final String? arrival;

  List<LatLng> get points => [for (final l in legs) ...l.points];
  Iterable<TransitLeg> get rides => legs.where((l) => !l.walk);
}

class TransitException implements Exception {
  const TransitException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TwoGisTransitService {
  TwoGisTransitService({
    required this.apiKey,
    http.Client? client,
    this.baseUrl = 'https://routing.api.2gis.com',
  }) : _client = client ?? http.Client();

  /// Ключ из `--dart-define=TWOGIS_KEY=...`; null — ключа нет.
  static TwoGisTransitService? fromEnvironment({http.Client? client}) {
    const key = String.fromEnvironment('TWOGIS_KEY');
    return key.isEmpty
        ? null
        : TwoGisTransitService(apiKey: key, client: client);
  }

  final String apiKey;
  final String baseUrl;
  final http.Client _client;

  Future<List<TransitOption>> plan(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      '$baseUrl/public_transport/2.0',
    ).replace(queryParameters: {'key': apiKey});
    final body = jsonEncode({
      'source': {
        'point': {'lat': from.latitude, 'lon': from.longitude},
      },
      'target': {
        'point': {'lat': to.latitude, 'lon': to.longitude},
      },
      // Маршрутки в 2ГИС — shuttle_bus.
      'transport': ['bus', 'trolleybus', 'shuttle_bus', 'tram'],
      'locale': 'ru',
    });
    final http.Response res;
    try {
      res = await _client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TransitException('2ГИС не ответил. Попробуйте ещё раз.');
    } catch (_) {
      throw const TransitException('Нет интернета — маршрут не построить.');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const TransitException('Ключ 2ГИС не подходит или закончился.');
    }
    if (res.statusCode == 204) return const [];
    if (res.statusCode != 200) {
      throw TransitException('2ГИС вернул ошибку ${res.statusCode}.');
    }
    return parseTwoGisTransit(utf8.decode(res.bodyBytes));
  }
}

/// Разбор ответа: массив вариантов (см. документацию 2ГИС).
List<TransitOption> parseTwoGisTransit(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } catch (_) {
    throw const TransitException('Не удалось прочитать ответ 2ГИС.');
  }
  final list = json is List
      ? json
      : (json is Map && json['result'] is List
            ? json['result'] as List
            : const []);

  final options = <TransitOption>[];
  for (final v in list) {
    if (v is! Map) continue;
    if (v['pedestrian'] == true) continue; // целиком пешком — это не автобус
    final legs = <TransitLeg>[];
    final movements = [
      for (final m in (v['movements'] as List?) ?? const [])
        if (m is Map) m,
    ];
    for (var i = 0; i < movements.length; i++) {
      final m = movements[i];
      final walk = m['type'] == 'walkway';
      final routes = (m['routes'] as List?) ?? const [];
      final lines = <String>[
        for (final r in routes)
          if (r is Map)
            for (final n in (r['names'] as List?) ?? const []) n.toString(),
      ];
      final kind = routes.isNotEmpty && routes.first is Map
          ? (routes.first as Map)['subtype'] as String?
          : null;
      final points = <LatLng>[];
      final alternatives = (m['alternatives'] as List?) ?? const [];
      if (alternatives.isNotEmpty && alternatives.first is Map) {
        for (final g
            in ((alternatives.first as Map)['geometry'] as List?) ?? const []) {
          if (g is Map && g['selection'] is String) {
            points.addAll(parseWktLine(g['selection'] as String));
          }
        }
      }
      final platforms = m['platforms'];
      final stopNames = platforms is Map
          ? (platforms['names'] as List?) ?? const []
          : const [];
      final waypoint = m['waypoint'];
      // Остановка выхода приходит как точка следующего участка.
      final nextWaypoint = i + 1 < movements.length
          ? movements[i + 1]['waypoint']
          : null;
      final toStop = !walk && nextWaypoint is Map
          ? _nonEmpty(nextWaypoint['name'])
          : null;
      legs.add(
        TransitLeg(
          walk: walk,
          lines: lines,
          kind: kind,
          fromStop: waypoint is Map ? _nonEmpty(waypoint['name']) : null,
          toStop: toStop,
          // В platforms — промежуточные остановки, без остановки выхода.
          stopCount: walk ? 0 : stopNames.length + 1,
          distance: (m['distance'] as num?)?.toDouble() ?? 0,
          movingSeconds: (m['moving_duration'] as num?)?.toDouble() ?? 0,
          waitingSeconds: (m['waiting_duration'] as num?)?.toDouble() ?? 0,
          points: points,
        ),
      );
    }
    if (!legs.any((l) => !l.walk)) continue;
    final schedules = (v['schedules'] as List?) ?? const [];
    final first = schedules.isEmpty ? null : schedules.first;
    options.add(
      TransitOption(
        legs: legs,
        totalSeconds: (v['total_duration'] as num?)?.toDouble() ?? 0,
        totalDistance: (v['total_distance'] as num?)?.toDouble() ?? 0,
        transfers:
            ((v['transfer_count'] as num?)?.toInt() ?? 0) +
            ((v['crossing_count'] as num?)?.toInt() ?? 0),
        departure: first is Map ? _nonEmpty(first['precise_time']) : null,
        intervalMinutes: first is Map
            ? (first['period'] as num?)?.toInt()
            : null,
        arrival: _arrival(movements),
      ),
    );
  }
  // Быстрее — выше; при равенстве — меньше пересадок.
  options.sort((a, b) {
    final t = a.totalSeconds.compareTo(b.totalSeconds);
    return t != 0 ? t : a.transfers.compareTo(b.transfers);
  });
  return options;
}

String? _arrival(List<Map> movements) {
  for (final m in movements.reversed) {
    final w = m['waypoint'];
    if (w is Map && w['comment'] is String) {
      final hit = RegExp(r'(\d{1,2}:\d{2})').firstMatch(w['comment'] as String);
      if (hit != null) return hit.group(1);
    }
  }
  return null;
}

String? _nonEmpty(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// `LINESTRING(lon lat, lon lat, …)` или `POINT(lon lat)` → точки.
/// В WKT сначала долгота, потом широта.
List<LatLng> parseWktLine(String wkt) {
  final open = wkt.indexOf('(');
  final close = wkt.lastIndexOf(')');
  if (open < 0 || close <= open) return const [];
  final inner = wkt
      .substring(open + 1, close)
      .replaceAll('(', '')
      .replaceAll(')', '');
  final points = <LatLng>[];
  for (final pair in inner.split(',')) {
    final xy = pair.trim().split(RegExp(r'\s+'));
    if (xy.length < 2) continue;
    final lon = double.tryParse(xy[0]);
    final lat = double.tryParse(xy[1]);
    if (lon != null && lat != null) points.add(LatLng(lat, lon));
  }
  return points;
}
