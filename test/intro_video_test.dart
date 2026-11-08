import 'package:apteka_ryadom/ui/widgets/intro_video_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Introduction works without a video and respects reduced motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(padding: EdgeInsets.all(20), child: IntroVideoCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Как это работает'), findsOneWidget);
      await tester.tap(find.text('Как это работает'));
      await tester.pumpAndSettle();
      expect(find.text('Найдите лекарство'), findsOneWidget);
      expect(find.text('Сравните аптеки'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
