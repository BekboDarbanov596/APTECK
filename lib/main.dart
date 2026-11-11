import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'data/catalog_repository.dart';
import 'l10n/lang.dart';
import 'logic/routing.dart';
import 'logic/transit.dart';
import 'state/app_state.dart';
import 'state/route_state.dart';
import 'state/theme_state.dart';
import 'ui/root_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(repository: const DemoCatalogRepository())..init();
  // Без настроенного Firebase приложение работает как раньше,
  // а экраны входа сообщают, что вход ещё не подключён.
  final auth = AuthService(FirebaseAuthBackend())..init();
  // Автобусы в приложении — если при сборке задан ключ 2ГИС (TWOGIS_KEY).
  final route = RouteState(RouteService(transit: TwoGisTransitService.fromEnvironment()));
  final lang = LangController()..load();
  final theme = ThemeController()..load();
  runApp(AptekaApp(state: state, auth: auth, route: route, lang: lang, theme: theme));
}

class AptekaApp extends StatelessWidget {
  const AptekaApp({
    super.key,
    required this.state,
    required this.auth,
    required this.route,
    this.lang,
    this.theme,
  });

  final AppState state;
  final AuthService auth;
  final RouteState route;

  /// Язык интерфейса; без него — русский.
  final LangController? lang;

  /// Тема оформления; без неё — светлая.
  final ThemeController? theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (t == null) return _build(context);
    return ThemeScope(
      controller: t,
      child: Builder(
        builder: (context) {
          // Подписка на смену темы и системной яркости.
          ThemeScope.maybeOf(context);
          final dark = t.isDark(MediaQuery.platformBrightnessOf(context));
          if (dark != AppColors.dark) {
            AppColors.dark = dark;
            // Цвета читаются напрямую из AppColors — перестраиваем всё дерево,
            // сохраняя состояние экранов.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              void rebuild(Element e) {
                e.markNeedsBuild();
                e.visitChildren(rebuild);
              }

              if (context.mounted) (context as Element).visitChildren(rebuild);
            });
          }
          return _build(context);
        },
      ),
    );
  }

  Widget _build(BuildContext context) {
    final app = AuthScope(
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
    final l = lang;
    return l == null ? app : LangScope(controller: l, child: app);
  }
}
