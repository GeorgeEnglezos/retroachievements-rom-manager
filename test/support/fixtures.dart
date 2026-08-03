import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared test data. Only helpers that were byte-identical across files live
/// here; per-file builders stay in their own file.

/// 1x1 transparent PNG, valid for Image.file in tests.
final kTinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// Widens the test surface to a desktop window. The app is desktop-first, so
/// its action bars are laid out wider than the default 800px test surface.
void useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
