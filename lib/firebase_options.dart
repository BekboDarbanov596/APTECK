// ВРЕМЕННЫЙ ФАЙЛ. Его полностью перезапишет команда:
//
//   flutterfire configure
//
// (см. README → «Вход и регистрация»). Пока Firebase-проект не подключён,
// приложение работает как раньше, а на экранах входа показывает,
// что вход ещё не настроен.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase не настроен: выполните `flutterfire configure`.',
      );
}
