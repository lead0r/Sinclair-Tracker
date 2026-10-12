import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinclair_tracker/main.dart';

void main() {
  test('selected brightness and colour palette survive a restart', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'theme_palette': 'emerald',
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = ThemeController(preferences);

    expect(controller.mode, ThemeMode.dark);
    expect(controller.palette, AppColorPalette.emerald);

    await controller.setMode(ThemeMode.light);
    await controller.setPalette(AppColorPalette.violet);
    final restored = ThemeController(preferences);

    expect(restored.mode, ThemeMode.light);
    expect(restored.palette, AppColorPalette.violet);
  });
}
