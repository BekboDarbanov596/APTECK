import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'tabs.dart';

/// Нижнее меню из трёх вкладок: Карта, Избранное, Профиль.
/// Поиск открывается из строки поиска на карте.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tab = 0;

  /// Выбрали лекарство где угодно — показываем аптеки на карте.
  void _showDrug(Drug drug) {
    AppScope.read(context).selectDrug(drug);
    setState(() => _tab = 0);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onOpenSearch: _openSearch),
          FavoritesScreen(onDrugPicked: _showDrug),
          ProfileScreen(
            onOpenFavorites: () => setState(() => _tab = 1),
            onDrugPicked: _showDrug,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Карта',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Избранное',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
