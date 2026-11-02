import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vastra_app/features/recreate/recreate_screen.dart';
import 'package:vastra_app/models/models.dart';

RecreateResult _sample() => RecreateResult.fromMap('r1', {
      'title': 'Casual Chic',
      'vibe': 'effortless, everyday',
      'summary': 'You’ve got lovely pieces, darling — we can get really close to this one!',
      'tip': 'Roll the tee sleeves once and tuck the front in for that easy French-girl shape.',
      'score': 80,
      'createdAt': 0,
      'pieces': [
        {
          'piece': 'Light brown short-sleeved top',
          'category': 'tops',
          'closeness': 'close',
          'note': 'Your camel tee has the same warm tone.',
          'item': {'id': 'a', 'name': 'Camel ribbed tee', 'category': 'tops'},
        },
        {
          'piece': 'Grey skinny jeans',
          'category': 'trousers',
          'closeness': 'exact',
          'note': 'Spot on.',
          'item': {'id': 'b', 'name': 'Charcoal slim jeans', 'category': 'trousers'},
        },
        {
          'piece': 'Tan suede ankle boots with a block heel',
          'category': 'shoes',
          'closeness': 'missing',
          'note': 'Look for tan suede boots — or wear white trainers for a sportier spin.',
          'item': null,
        },
      ],
    });

void main() {
  testWidgets('recreate result fits a phone screen and offers every action', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecreateResultView(
            result: _sample(),
            photo: null,
            wearing: false,
            openingTryOn: false,
            onWear: () => tapped.add('wear'),
            onTryMine: () => tapped.add('mine'),
            onTryOriginal: () => tapped.add('original'),
            onTryPiece: (id) => tapped.add('piece:$id'),
            onAnother: () => tapped.add('another'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Casual Chic'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Close match'), findsOneWidget);
    expect(find.text('Perfect match'), findsOneWidget);
    await tester.tap(find.byTooltip('Try on').first);
    await tester.scrollUntilVisible(find.text('Not in your closet yet'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Missing'), findsOneWidget);

    for (final label in ['Wear my version today', 'Try my version on', 'Try the original look on me', 'Recreate another look']) {
      await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(label));
    }
    expect(tapped, ['piece:a', 'wear', 'mine', 'original', 'another']);
    expect(tester.takeException(), isNull);
  });
}
