import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/models.dart';
import '../logic/routing.dart';

/// Текущий маршрут до аптеки: цель, режим, результат, загрузка, ошибка.
class RouteState extends ChangeNotifier {
  RouteState(this._service);

  final RouteService _service;

  Pharmacy? target;
  LatLng? from;

  /// true — старт по геолокации, false — от площади Ала-Тоо.
  bool fromDevice = false;
  TravelMode mode = TravelMode.walk;
  RouteResult? result;
  bool loading = false;
  String? error;

  /// По 2ГИС автобус не нужен — панель предложит идти пешком.
  bool walkInstead = false;

  /// Пока маршрут не показан на карте — вкладка «Карта» должна открыться.
  bool _showMapPending = false;
  int _request = 0;

  bool get active => target != null;

  /// Уже известное время в пути для этой аптеки — для нижней полоски способов.
  final Map<TravelMode, double> knownDurations = {};

  /// Этот способ строится прямо в приложении (автобус — только с ключом 2ГИС).
  bool get inApp => _service.canRouteInApp(mode);

  Future<void> buildTo(
    Pharmacy pharmacy, {
    required LatLng from,
    required bool fromDevice,
  }) {
    if (target?.id != pharmacy.id || this.from != from) knownDurations.clear();
    target = pharmacy;
    this.from = from;
    this.fromDevice = fromDevice;
    _showMapPending = true;
    return _load();
  }

  Future<void> setMode(TravelMode value) async {
    if (value == mode) return;
    mode = value;
    if (active) await _load();
  }

  Future<void> retry() => _load();

  /// Выбранный вариант поездки на автобусе.
  int get transitIndex {
    final r = result;
    if (r?.transit == null) return 0;
    return r!.transitOptions.indexOf(r.transit!).clamp(0, 1 << 20);
  }

  /// Листаем карточки вариантов — на карте перерисовывается выбранный.
  void selectTransit(int index) {
    final r = result;
    if (r == null || index < 0 || index >= r.transitOptions.length) return;
    if (index == transitIndex) return;
    result = transitToRoute(r.transitOptions[index], options: r.transitOptions);
    notifyListeners();
  }

  /// Вернёт true один раз после запроса маршрута — чтобы переключиться на карту.
  bool takeShowMapRequest() {
    final pending = _showMapPending;
    _showMapPending = false;
    return pending;
  }

  void clear() {
    _request++;
    target = null;
    result = null;
    error = null;
    walkInstead = false;
    loading = false;
    notifyListeners();
  }

  Future<void> _load() async {
    final t = target, f = from;
    if (t == null || f == null) return;
    final request = ++_request;
    // Автобус без ключа 2ГИС: у нас не строим — панель предложит 2ГИС.
    if (!_service.canRouteInApp(mode)) {
      loading = false;
      error = null;
      result = null;
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    walkInstead = false;
    result = null;
    notifyListeners();
    try {
      final r = await _service.route(f, LatLng(t.lat, t.lng), mode);
      if (request != _request) return; // уже запросили другой маршрут
      result = r;
      knownDurations[mode] = r.duration;
    } on RoutingException catch (e) {
      if (request != _request) return;
      error = e.message;
      walkInstead = e is NoTransitException;
    } catch (_) {
      if (request != _request) return;
      error = 'Не удалось построить маршрут.';
    }
    loading = false;
    notifyListeners();
  }
}

class RouteScope extends InheritedNotifier<RouteState> {
  const RouteScope({super.key, required RouteState route, required super.child})
    : super(notifier: route);

  static RouteState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RouteScope>()?.notifier;

  static RouteState? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RouteScope>()?.notifier;
}
