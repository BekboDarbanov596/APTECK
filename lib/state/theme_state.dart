import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Тема оформления: светлая, тёмная (ночная, как в 2ГИС) или как в системе.
enum AppThemeMode { light, dark, system }

/// Выбранная тема. Сохраняется на устройстве.
class ThemeController extends ChangeNotifier {
  ThemeController({this.initial = AppThemeMode.light, this.persist = true})
      : _mode = initial;

  static const _prefKey = 'app_theme';
  final AppThemeMode initial;
  final bool persist;
  AppThemeMode _mode;

  AppThemeMode get mode => _mode;

  Future<void> load() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      final found = AppThemeMode.values.where((m) => m.name == saved);
      if (found.isNotEmpty && found.first != _mode) {
        _mode = found.first;
        notifyListeners();
      }
    } catch (_) {
      // Нет хранилища (тесты, приватный режим) — остаёмся на выбранной.
    }
  }

  Future<void> set(AppThemeMode value) async {
    if (value == _mode) return;
    _mode = value;
    notifyListeners();
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, value.name);
    } catch (_) {}
  }

  /// Тёмная ли тема сейчас, с учётом системной настройки.
  bool isDark(Brightness platform) => switch (_mode) {
        AppThemeMode.light => false,
        AppThemeMode.dark => true,
        AppThemeMode.system => platform == Brightness.dark,
      };
}

/// Даёт тему всему дереву.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
