import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native iOS navbar keeps tab items icon-only', () {
    final source = File(
      'ios/Runner/NativeGlassTabBar.swift',
    ).readAsStringSync();

    expect(source, contains('UITabBarItem(title: nil'));
    expect(source, isNot(contains('UITabBarItem(title: tab.label')));
  });
}
