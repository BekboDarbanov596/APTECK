import 'dart:async';

import 'package:apteka_ryadom/auth/auth_service.dart';
import 'package:apteka_ryadom/auth/validators.dart';
import 'package:apteka_ryadom/ui/auth/account_card.dart';
import 'package:apteka_ryadom/ui/auth/login_screen.dart';
import 'package:apteka_ryadom/ui/auth/register_screen.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Поддельная авторизация: хранит аккаунты в памяти.
class FakeBackend implements AuthBackend {
  FakeBackend({this.configured = true});

  final bool configured;
  final _users = StreamController<AppUser?>.broadcast();
  final accounts = <String, (String name, String password)>{};
  Object? googleResult; // null — успех, иначе бросаем это
  String? resetSentTo;

  @override
  Future<bool> initialize() async => configured;

  @override
  Stream<AppUser?> userChanges() => _users.stream;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    final acc = accounts[email];
    if (acc == null || acc.$2 != password) {
      throw AuthFailure(authErrorMessage('invalid-credential')!);
    }
    _users.add(AppUser(uid: email, name: acc.$1, email: email));
  }

  @override
  Future<void> register({required String name, required String email, required String password}) async {
    if (accounts.containsKey(email)) {
      throw AuthFailure(authErrorMessage('email-already-in-use')!);
    }
    accounts[email] = (name, password);
    _users.add(AppUser(uid: email, name: name, email: email));
  }

  @override
  Future<void> signInWithGoogle() async {
    if (googleResult != null) throw googleResult!;
    _users.add(const AppUser(uid: 'g', name: 'Айгуль Асанова', email: 'aigul@example.com'));
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetSentTo = email;

  @override
  Future<void> signOut() async => _users.add(null);
}

Future<AuthService> makeAuth(FakeBackend backend) async {
  final auth = AuthService(backend);
  await auth.init();
  return auth;
}

Widget app(AuthService auth, Widget home) => AuthScope(
      auth: auth,
      child: MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: Builder(builder: (_) => home)),
      ),
    );

/// Экран открывается поверх «профиля», чтобы после входа было куда вернуться.
Widget appWithProfile(AuthService auth, Widget screen) => AuthScope(
      auth: auth,
      child: MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const AccountCard(),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => screen)),
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

/// Объект 3D крутится бесконечно — pumpAndSettle не дождётся,
/// поэтому прокручиваем время вручную.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('Проверка полей', () {
    test('почта', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('abc'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail(' user@mail.kg '), isNull);
    });

    test('пароль при регистрации', () {
      expect(validateNewPassword('short1'), 'Минимум 8 символов');
      expect(validateNewPassword('longpassword'), 'Добавьте хотя бы одну цифру');
      expect(validateNewPassword('12345678'), 'Добавьте хотя бы одну букву');
      expect(validateNewPassword('apteka2026'), isNull);
      expect(validatePasswordRepeat('a', 'b'), isNotNull);
      expect(validatePasswordRepeat('a', 'a'), isNull);
    });

    test('имя', () {
      expect(validateName(' '), isNotNull);
      expect(validateName('А'), isNotNull);
      expect(validateName('Бекбо'), isNull);
    });

    test('ошибки Firebase переводятся, отмена — без сообщения', () {
      expect(authErrorMessage('wrong-password'), 'Неверная почта или пароль.');
      expect(authErrorMessage('popup-closed-by-user'), isNull);
      expect(authErrorMessage('что-то-новое'), isNotNull);
    });
  });

  group('Сервис', () {
    test('без Firebase-проекта вход честно недоступен', () async {
      final auth = await makeAuth(FakeBackend(configured: false));
      expect(auth.status, AuthStatus.notConfigured);
      expect(() => auth.signInWithGoogle(), throwsA(isA<AuthFailure>()));
    });

    test('регистрация и вход', () async {
      final backend = FakeBackend();
      final auth = await makeAuth(backend);
      await auth.register(name: ' Бекбо ', email: ' b@mail.kg ', password: 'apteka2026');
      await Future<void>.delayed(Duration.zero);
      expect(auth.user?.name, 'Бекбо');
      expect(backend.accounts.keys, ['b@mail.kg']);
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(auth.isSignedIn, isFalse);
      await auth.signInWithEmail('b@mail.kg', 'apteka2026');
      await Future<void>.delayed(Duration.zero);
      expect(auth.user?.email, 'b@mail.kg');
      expect(auth.user?.initials, 'Б');
    });
  });

  testWidgets('Вход: пустая форма не отправляется, неверный пароль — понятная ошибка',
      (tester) async {
    final backend = FakeBackend()..accounts['b@mail.kg'] = ('Бекбо', 'apteka2026');
    final auth = await makeAuth(backend);
    await tester.pumpWidget(app(auth, const LoginScreen()));
    await settle(tester);

    await tester.tap(find.text('Войти'));
    await settle(tester);
    expect(find.text('Введите почту'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'b@mail.kg');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('Войти'));
    await settle(tester);
    expect(find.text('Неверная почта или пароль.'), findsOneWidget);
    expect(auth.isSignedIn, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Вход почтой возвращает в профиль, там видно имя и «Выйти»', (tester) async {
    final backend = FakeBackend()..accounts['b@mail.kg'] = ('Бекбо', 'apteka2026');
    final auth = await makeAuth(backend);
    await tester.pumpWidget(appWithProfile(auth, const LoginScreen()));
    expect(find.text('Аккаунт'), findsOneWidget);

    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'b@mail.kg');
    await tester.enterText(find.byType(TextFormField).at(1), 'apteka2026');
    await tester.tap(find.text('Войти'));
    await settle(tester);

    expect(find.text('С возвращением'), findsNothing);
    expect(find.text('Бекбо'), findsOneWidget);
    await tester.tap(find.text('Выйти'));
    await settle(tester);
    expect(auth.isSignedIn, isFalse);
    expect(find.text('Аккаунт'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Регистрация: проверка паролей и создание аккаунта', (tester) async {
    final backend = FakeBackend();
    final auth = await makeAuth(backend);
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(appWithProfile(auth, const RegisterScreen()));
    await tester.tap(find.text('open'));
    await settle(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Бекбо');
    await tester.enterText(fields.at(1), 'b@mail.kg');
    await tester.enterText(fields.at(2), 'apteka2026');
    await tester.enterText(fields.at(3), 'apteka2027');
    await tester.tap(find.text('Создать аккаунт').last);
    await settle(tester);
    expect(find.text('Пароли не совпадают'), findsOneWidget);
    expect(backend.accounts, isEmpty);

    await tester.enterText(fields.at(3), 'apteka2026');
    await tester.tap(find.text('Создать аккаунт').last);
    await settle(tester);
    expect(backend.accounts.keys, ['b@mail.kg']);
    expect(find.text('Бекбо'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Google: отмена — тихо, успех — вход', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = FakeBackend()..googleResult = const AuthCancelled();
    final auth = await makeAuth(backend);
    await tester.pumpWidget(appWithProfile(auth, const LoginScreen()));
    await tester.tap(find.text('open'));
    await settle(tester);

    await tester.tap(find.text('Продолжить с Google'));
    await settle(tester);
    expect(find.byType(SnackBar), findsNothing);
    expect(auth.isSignedIn, isFalse);

    backend.googleResult = null;
    await tester.tap(find.text('Продолжить с Google'));
    await settle(tester);
    expect(auth.user?.name, 'Айгуль Асанова');
    expect(find.text('Айгуль Асанова'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Без Firebase-проекта экран предупреждает, а вход выдаёт понятную ошибку',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = await makeAuth(FakeBackend(configured: false));
    await tester.pumpWidget(app(auth, const LoginScreen()));
    await settle(tester);
    expect(find.textContaining('Firebase-проект ещё не настроен'), findsOneWidget);
    await tester.tap(find.text('Продолжить с Google'));
    await settle(tester);
    expect(find.textContaining('Вход пока не подключён'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 400.0]) {
    for (final screen in <Widget>[const LoginScreen(), const RegisterScreen()]) {
      testWidgets('${screen.runtimeType} помещается на экране шириной $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = await makeAuth(FakeBackend());
        await tester.pumpWidget(app(auth, screen));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('Карточка аккаунта без AuthScope ничего не показывает', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AccountCard())));
    expect(find.text('Аккаунт'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
