import 'dart:convert';
import 'dart:io';

import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/assistant.dart';
import 'package:apteka_ryadom/logic/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = Catalog.fromJson(
    jsonDecode(File('assets/demo_data.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final noon = DateTime(2026, 11, 8, 12);

  AssistantReply ask(String m) => assistantReply(
    message: m,
    catalog: catalog,
    userLat: bishkekCenterLat,
    userLng: bishkekCenterLng,
    now: noon,
  );

  List<String> ids(AssistantReply r) => r.suggestions.map((d) => d.id).toList();

  group('Язык', () {
    test('русский, кыргызский, английский', () {
      expect(detectLang('Где есть Нурофен?'), AssistantLang.ru);
      expect(detectLang('Нурофен кайда бар?'), AssistantLang.ky);
      expect(detectLang('Башым ооруп жатат'), AssistantLang.ky);
      expect(detectLang('Where can I buy Nurofen?'), AssistantLang.en);
    });

    test('лекарство — ответ на языке вопроса', () {
      final ru = ask('Где есть Нурофен?');
      final ky = ask('Нурофен кайда бар?');
      final en = ask('Where can I buy Nurofen?');
      for (final r in [ru, ky, en]) {
        expect(r.drug?.id, 'nurofen-200');
      }
      expect(ru.text, contains('Ближайшая'));
      expect(ky.text, contains('Эң жакыны'));
      expect(en.text, contains('Nearest'));
      expect(en.text, contains('som'));
      expect(en.text, isNot(contains('сом')));
    });
  });

  group('Темы аптеки', () {
    test('самса → отравление: Смекта, уголь, когда к врачу', () {
      final r = ask('съел самсу');
      expect(r.lang, AssistantLang.ru);
      expect(r.drug, isNull);
      expect(ids(r), containsAll(['smecta-3', 'activated-carbon']));
      expect(r.text, contains('отравлен'));
      expect(r.text, contains('103'));
    });

    test('самса по-кыргызски и по-английски', () {
      final ky = ask('Самса жедим, курсагым ооруйт');
      expect(ky.lang, AssistantLang.ky);
      expect(ids(ky), contains('smecta-3'));
      expect(ky.text, contains('уулан'));

      final en = ask('I ate shawarma and my stomach hurts');
      expect(en.lang, AssistantLang.en);
      expect(ids(en), contains('smecta-3'));
      expect(en.text, contains('Smecta'));
      expect(en.text, contains('food poisoning'));
    });

    test('разные темы ведут к своим препаратам', () {
      expect(
        ids(ask('болит голова и температура')),
        contains('paracetamol-500'),
      );
      expect(ids(ask('насморк и кашель')), contains('nazivin-005'));
      expect(ids(ask('Мурунум бүтүп калды')), contains('nazivin-005'));
      expect(ids(ask('allergy to pollen')), contains('loratadin-10'));
      expect(
        ids(ask('болит спина после спортзала')),
        contains('diclofenac-50'),
      );
      expect(ids(ask('изжога после шаурмы')), contains('omeprazol-20'));
      expect(ids(ask('порезал палец')), contains('levomekol-40'));
      expect(ids(ask('болезненные месячные')), contains('drotaverin-40'));
    });

    test('рецептурное по симптомам не советует', () {
      for (final m in [
        'болит сердце',
        'нужен антибиотик от горла',
        'высокое давление',
      ]) {
        expect(ask(m).suggestions.any((d) => d.rx), isFalse, reason: m);
      }
      expect(ask('высокое давление').text, contains('по рецепту'));
    });

    test('опасные симптомы — сразу 103, без лекарств', () {
      for (final m in [
        'сильная боль в груди',
        'дем ала албай жатам',
        "I can't breathe",
      ]) {
        final r = ask(m);
        expect(r.text, contains('103'), reason: m);
        expect(r.suggestions, isEmpty, reason: m);
      }
    });

    test('дети — предупреждение про дозы', () {
      expect(ask('у ребенка температура').text, contains('детей'));
    });

    test('конкретное лекарство важнее темы', () {
      expect(ask('съел самсу, где есть смекта?').drug?.id, 'smecta-3');
    });
  });

  group('Не по теме', () {
    test('возвращает к аптечным темам на нужном языке', () {
      expect(
        ask('какая завтра погода в Бишкеке?').text,
        contains('только на аптечные темы'),
      );
      expect(
        ask('Эртең аба ырайы кандай болот?').text,
        contains('дарыкана темалары'),
      );
      expect(
        ask(
          'who won the football match yesterday? tell me a joke please about cats',
        ).lang,
        AssistantLang.en,
      );
    });

    test('приветствие и спасибо', () {
      expect(ask('Салам').text, contains('Саламатсызбы'));
      expect(ask('hello').text, contains('Hello'));
      expect(ask('спасибо').text, contains('Пожалуйста'));
      expect(ask('как дела').text, contains('всё хорошо'));
      expect(ask('Кандайсың?').text, contains('Рахмат'));
      expect(ask('how are you?').text, contains("I'm good"));
    });
  });
}
