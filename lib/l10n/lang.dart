import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

/// Язык интерфейса.
enum AppLang {
  ru('Русский', 'RU'),
  ky('Кыргызча', 'KG'),
  en('English', 'EN');

  const AppLang(this.title, this.short);

  /// Название языка на самом языке — так его легко узнать в списке.
  final String title;
  final String short;
}

/// Выбранный язык. Сохраняется на устройстве.
class LangController extends ChangeNotifier {
  LangController({AppLang initial = AppLang.ru, this.persist = true}) : _lang = initial;

  static const _prefKey = 'app_lang';
  final bool persist;
  AppLang _lang;

  AppLang get lang => _lang;

  Future<void> load() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      final found = AppLang.values.where((l) => l.name == saved);
      if (found.isNotEmpty && found.first != _lang) {
        _lang = found.first;
        notifyListeners();
      }
    } catch (_) {
      // Нет хранилища (тесты, приватный режим) — остаёмся на русском.
    }
  }

  Future<void> set(AppLang value) async {
    if (value == _lang) return;
    _lang = value;
    notifyListeners();
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, value.name);
    } catch (_) {}
  }
}

/// Даёт язык всему дереву виджетов; при смене языка они перестраиваются.
class LangScope extends InheritedNotifier<LangController> {
  const LangScope({super.key, required LangController controller, required super.child})
      : super(notifier: controller);

  static LangController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LangScope>()?.notifier;
}

/// Текущий язык (русский, если язык не настроен — например, в тестах).
AppLang langOf(BuildContext context) => LangScope.maybeOf(context)?.lang ?? AppLang.ru;

/// Перевод строки интерфейса. Ключ — русский текст; если перевода нет,
/// показываем русский. Подстановки: `{n}` → [args].
String tr(BuildContext context, String ru, [Map<String, Object> args = const {}]) {
  var out = switch (langOf(context)) {
    AppLang.ru => ru,
    AppLang.ky => uiStrings[ru]?.$1 ?? ru,
    AppLang.en => uiStrings[ru]?.$2 ?? ru,
  };
  args.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
  return out;
}
