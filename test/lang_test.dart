import 'package:apteka_ryadom/l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Язык интерфейса: перевод и перестройка при смене', (
    tester,
  ) async {
    final lang = LangController(persist: false);
    await tester.pumpWidget(
      LangScope(
        controller: lang,
        child: MaterialApp(
          home: Builder(
            builder: (context) =>
                Text(tr(context, 'Профиль') + tr(context, 'Карта')),
          ),
        ),
      ),
    );
    expect(find.text('ПрофильКарта'), findsOneWidget);

    await lang.set(AppLang.en);
    await tester.pump();
    expect(find.text('ProfileMap'), findsOneWidget);

    await lang.set(AppLang.ky);
    await tester.pump();
    expect(find.text('ПрофильКарта'), findsOneWidget); // в кыргызском так же
    expect(find.text('ProfileMap'), findsNothing);
  });

  testWidgets('Без LangScope — русский, неизвестная строка — как есть', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text(tr(context, 'Строка без перевода')),
        ),
      ),
    );
    expect(find.text('Строка без перевода'), findsOneWidget);
  });
}
