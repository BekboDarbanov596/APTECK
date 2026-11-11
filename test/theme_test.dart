import 'package:apteka_ryadom/state/theme_state.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:apteka_ryadom/ui/widgets/map_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppColors.dark = false);

  test('тема: светлая, тёмная, как в системе', () async {
    final t = ThemeController(persist: false);
    expect(t.isDark(Brightness.dark), isFalse); // по умолчанию светлая
    await t.set(AppThemeMode.dark);
    expect(t.isDark(Brightness.light), isTrue);
    await t.set(AppThemeMode.system);
    expect(t.isDark(Brightness.light), isFalse);
    expect(t.isDark(Brightness.dark), isTrue);
  });

  test('палитра меняется, тема Material — тоже', () {
    final lightText = AppColors.text;
    expect(buildTheme().brightness, Brightness.light);
    AppColors.dark = true;
    expect(AppColors.text, isNot(lightText));
    expect(AppColors.background.computeLuminance(), lessThan(0.05));
    expect(buildTheme().brightness, Brightness.dark);
  });

  test('ночью карта тёмная, но выбранная вручную «Схема» — светлая', () {
    expect(MapLayer.auto(dark: true), MapLayer.dark);
    expect(MapLayer.auto(dark: false), MapLayer.scheme);
    expect(MapLayer.auto(dark: true, chosen: MapLayer.scheme), MapLayer.scheme);
    expect(MapLayer.auto(dark: false, chosen: MapLayer.dark), MapLayer.dark);
  });
}
