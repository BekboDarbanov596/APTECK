import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'data/catalog_repository.dart';
import 'logic/routing.dart';
import 'state/app_state.dart';
import 'state/route_state.dart';
import 'ui/root_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(repository: const DemoCatalogRepository())..init();
  // Без настроенного Firebase приложение работает как раньше,
  // а экраны входа сообщают, что вход ещё не подключён.
  final auth = AuthService(FirebaseAuthBackend())..init();
  final route = RouteState(RouteService());
  runApp(AptekaApp(state: state, auth: auth, route: route));
}

class AptekaApp extends StatelessWidget {
  const AptekaApp({super.key, required this.state, required this.auth, required this.route});

  final AppState state;
  final AuthService auth;
  final RouteState route;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: auth,
      child: AppScope(
        state: state,
        child: RouteScope(
          route: route,
          child: MaterialApp(
          title: 'Аптека рядом',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          // Шторку и карусель можно тянуть и мышью — для показа с ноутбука.
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: PointerDeviceKind.values.toSet(),
          ),
          home: const RootScreen(),
          ),
        ),
      ),
    );
  }
}
