import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vastra_app/widgets/pip.dart';

Future<void> _pumpPipAt(WidgetTester tester, Alignment alignment) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(393, 852), padding: EdgeInsets.only(top: 54, bottom: 34)),
        child: Scaffold(
          body: Align(
            alignment: alignment,
            child: const Pip(
              PipPose.happy,
              size: 90,
              popIn: false,
              motion: PipMotion.still,
              quips: ['Outfit of the day? Say less — and a little bit longer so it has to wrap nicely.'],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() => precacheImage(AssetImage(PipPose.happy.asset), tester.element(find.byType(Pip))));
  await tester.pump();
}

void _expectQuipOnScreen(WidgetTester tester) {
  final bubble = find.byType(PipBubble);
  expect(bubble, findsOneWidget);
  final rect = tester.getRect(bubble);
  expect(rect.left, greaterThanOrEqualTo(12), reason: 'left edge $rect');
  expect(rect.right, lessThanOrEqualTo(393 - 12), reason: 'right edge $rect');
  expect(rect.top, greaterThanOrEqualTo(54), reason: 'clear of the status bar $rect');
  expect(rect.bottom, lessThanOrEqualTo(852), reason: 'bottom edge $rect');
}

void main() {
  for (final (name, alignment) in [
    ('left edge', Alignment.centerLeft),
    ('right edge', Alignment.centerRight),
    ('top-left under the status bar', const Alignment(-1, -0.92)),
  ]) {
    testWidgets('quip stays inside the screen when Pip is at the $name', (tester) async {
      await _pumpPipAt(tester, alignment);
      await tester.tap(find.byType(Pip));
      await tester.pump(const Duration(milliseconds: 400));
      _expectQuipOnScreen(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(PipBubble), findsNothing, reason: 'quip hides again');
    });
  }
}
