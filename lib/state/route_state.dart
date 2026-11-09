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

  /// Пока маршрут не показан на карте — вкладка «Карта» должна открыться.
  bool _showMapPending = false;
  int _request = 0;

  bool get active => target != null;

  Future<void> buildTo(
    Pharmacy pharmacy, {
    required LatLng from,
    required bool fromDevice,
  }) {
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
    loading = false;
    notifyListeners();
  }

  Future<void> _load() async {
    final t = target, f = from;
    if (t == null || f == null) return;
    final request = ++_request;
    loading = true;
    error = null;
    result = null;
    notifyListeners();
    try {
      final r = await _service.route(f, LatLng(t.lat, t.lng), mode);
      if (request != _request) return; // уже запросили другой маршрут
      result = r;
    } on RoutingException catch (e) {
      if (request != _request) return;
      error = e.message;
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
