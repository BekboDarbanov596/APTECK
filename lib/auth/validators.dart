/// Проверки полей форм входа и регистрации. null — всё в порядке.
library;

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Введите почту';
  if (!_emailRe.hasMatch(v)) return 'Похоже, в почте ошибка';
  return null;
}

/// Firebase требует минимум 6 символов; просим 8 и хотя бы одну цифру.
String? validateNewPassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Придумайте пароль';
  if (v.length < 8) return 'Минимум 8 символов';
  if (!RegExp(r'\d').hasMatch(v)) return 'Добавьте хотя бы одну цифру';
  if (!RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(v)) return 'Добавьте хотя бы одну букву';
  return null;
}

String? validateLoginPassword(String? value) =>
    (value ?? '').isEmpty ? 'Введите пароль' : null;

String? validateName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Как к вам обращаться?';
  if (v.length < 2) return 'Слишком короткое имя';
  if (v.length > 40) return 'Слишком длинное имя';
  return null;
}

String? validatePasswordRepeat(String? value, String password) =>
    value == password ? null : 'Пароли не совпадают';
