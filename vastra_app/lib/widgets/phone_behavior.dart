import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Scrolling that feels like a phone everywhere: drag with a finger, mouse or
/// trackpad, and no desktop scrollbars.
class PhoneScrollBehavior extends MaterialScrollBehavior {
  const PhoneScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// On the web the app always behaves like the iPhone build (sizing, page
/// transitions, bouncy scrolling), even in a desktop browser.
ThemeData phoneTheme(ThemeData base) {
  if (!kIsWeb) return base;
  return base.copyWith(
    platform: TargetPlatform.iOS,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// Screens with dark backgrounds (like the camera) flip the framed status bar to white.
final ValueNotifier<bool> frameStatusBarLight = ValueNotifier(false);
