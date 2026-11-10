import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../state/route_state.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'tabs.dart';

/// Главный экран — карта без нижнего меню (как в 2ГИС).
/// Профиль открывается кнопкой справа сверху, избранное — из профиля,
/// поиск — из строки поиска в шторке.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  void _backToMap() => Navigator.of(context).popUntil((r) => r.isFirst);

  /// Выбрали лекарство где угодно — показываем аптеки на карте.
  void _showDrug(Drug drug) {
    AppScope.read(context).selectDrug(drug);
    _backToMap();
  }

  void _openSearch({bool voice = false}) {
    Navigator.of(context).push(
      flipRoute(
        Builder(
          builder: (routeContext) => SearchScreen(
            startVoice: voice,
            onPicked: (drug) {
              Navigator.of(routeContext).pop();
              _showDrug(drug);
            },
          ),
        ),
      ),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(flipRoute(FavoritesScreen(onDrugPicked: _showDrug)));
  }

  void _openProfile() {
    Navigator.of(context).push(
      flipRoute(ProfileScreen(onOpenFavorites: _openFavorites, onDrugPicked: _showDrug)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Маршрут запросили с другого экрана (избранное, аптека) — возвращаемся к карте.
    final route = RouteScope.maybeOf(context);
    if (route != null && route.active && route.takeShowMapRequest()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _backToMap();
      });
    }
    return HomeScreen(onOpenSearch: _openSearch, onOpenProfile: _openProfile);
  }
}
