import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

/// Вошедший пользователь — только то, что нужно интерфейсу.
class AppUser {
  const AppUser({required this.uid, this.name, this.email, this.photoUrl});

  final String uid;
  final String? name;
  final String? email;
  final String? photoUrl;

  /// «АБ» — для аватара без фото.
  String get initials {
    final source = (name?.trim().isNotEmpty ?? false) ? name!.trim() : (email ?? '?');
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return source.characters.first.toUpperCase();
  }
}

/// Понятная ошибка для показа человеку.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Человек сам закрыл окно Google — это не ошибка, сообщение не показываем.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Источник авторизации. Настоящий — [FirebaseAuthBackend], в тестах — подделка.
abstract interface class AuthBackend {
  /// false — Firebase-проект не подключён (`flutterfire configure` не выполнен).
  Future<bool> initialize();
  Stream<AppUser?> userChanges();
  Future<void> signInWithEmail(String email, String password);
  Future<void> register({required String name, required String email, required String password});
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

enum AuthStatus { starting, notConfigured, ready }

/// Состояние входа для всего приложения.
class AuthService extends ChangeNotifier {
  AuthService(this._backend);

  final AuthBackend _backend;
  StreamSubscription<AppUser?>? _sub;

  AuthStatus status = AuthStatus.starting;
  AppUser? user;
  bool get isSignedIn => user != null;
  bool get isConfigured => status == AuthStatus.ready;

  Future<void> init() async {
    final ok = await _backend.initialize();
    status = ok ? AuthStatus.ready : AuthStatus.notConfigured;
    if (ok) {
      _sub = _backend.userChanges().listen((u) {
        user = u;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const AuthFailure(
        'Вход пока не подключён: Firebase-проект ещё не настроен.',
      );
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _ensureConfigured();
    await _backend.signInWithEmail(email.trim(), password);
  }

  Future<void> register({required String name, required String email, required String password}) async {
    _ensureConfigured();
    await _backend.register(name: name.trim(), email: email.trim(), password: password);
  }

  Future<void> signInWithGoogle() async {
    _ensureConfigured();
    await _backend.signInWithGoogle();
  }

  Future<void> sendPasswordReset(String email) async {
    _ensureConfigured();
    await _backend.sendPasswordReset(email.trim());
  }

  Future<void> signOut() => _backend.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Реальная авторизация через Firebase Authentication.
class FirebaseAuthBackend implements AuthBackend {
  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;
  bool _googleReady = false;

  @override
  Future<bool> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      return true;
    } catch (e) {
      debugPrint('Firebase не инициализирован: $e');
      return false;
    }
  }

  @override
  Stream<AppUser?> userChanges() => _auth.userChanges().map(
        (u) => u == null
            ? null
            : AppUser(uid: u.uid, name: u.displayName, email: u.email, photoUrl: u.photoURL),
      );

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email, password: password));

  @override
  Future<void> register({required String name, required String email, required String password}) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        await cred.user?.updateDisplayName(name);
        await cred.user?.reload();
      });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        if (kIsWeb) {
          // В браузере — всплывающее окно Google от Firebase.
          await _auth.signInWithPopup(fb.GoogleAuthProvider());
          return;
        }
        final google = GoogleSignIn.instance;
        if (!_googleReady) {
          await google.initialize();
          _googleReady = true;
        }
        if (!google.supportsAuthenticate()) {
          throw const AuthFailure('Вход через Google на этом устройстве недоступен.');
        }
        final account = await google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw const AuthFailure('Google не вернул данные для входа. Попробуйте ещё раз.');
        }
        await _auth.signInWithCredential(fb.GoogleAuthProvider.credential(idToken: idToken));
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  @override
  Future<void> signOut() async {
    if (!kIsWeb && _googleReady) {
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  /// Переводит ошибки Firebase и Google в понятные сообщения.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on AuthFailure {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthCancelled();
      }
      debugPrint('GoogleSignInException: ${e.code} ${e.description}');
      throw const AuthFailure('Не удалось войти через Google. Попробуйте ещё раз.');
    } on fb.FirebaseAuthException catch (e) {
      final message = authErrorMessage(e.code);
      if (message == null) throw const AuthCancelled();
      throw AuthFailure(message);
    }
  }
}

/// Сообщение по коду ошибки Firebase Auth. null — человек сам отменил вход.
String? authErrorMessage(String code) => switch (code) {
      'popup-closed-by-user' || 'cancelled-popup-request' || 'user-cancelled' => null,
      'invalid-email' => 'Похоже, в почте ошибка.',
      'user-disabled' => 'Этот аккаунт заблокирован.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' || 'INVALID_LOGIN_CREDENTIALS' =>
        'Неверная почта или пароль.',
      'email-already-in-use' => 'Аккаунт с этой почтой уже есть — войдите.',
      'weak-password' => 'Пароль слишком простой.',
      'too-many-requests' => 'Слишком много попыток. Подождите немного.',
      'network-request-failed' => 'Нет интернета. Проверьте подключение.',
      'operation-not-allowed' => 'Этот способ входа не включён в настройках Firebase.',
      'account-exists-with-different-credential' =>
        'Эта почта уже зарегистрирована другим способом входа.',
      'popup-blocked' => 'Браузер заблокировал окно входа. Разрешите всплывающие окна.',
      'unauthorized-domain' => 'Этот адрес сайта не разрешён в настройках Firebase.',
      _ => 'Не удалось войти. Попробуйте ещё раз.',
    };

/// Доступ к [AuthService] из виджетов: `AuthScope.of(context)`.
class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({super.key, required AuthService auth, required super.child})
      : super(notifier: auth);

  static AuthService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;

  /// null, если выше по дереву нет [AuthScope] (например, в отдельных тестах экранов).
  static AuthService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;

  static AuthService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}
