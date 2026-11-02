import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vastra_app/features/dress_up/dress_up_screen.dart';
import 'package:vastra_app/models/models.dart';
import 'package:vastra_app/providers/auth_controller.dart';
import 'package:vastra_app/providers/today_controller.dart';

class _FakeAuth extends ChangeNotifier implements AuthController {
  @override
  String? get uid => 'u1';

  @override
  UserProfile? get profile => UserProfile.fromMap('u1', {
    'displayName': 'Ana',
    'tryOnPhotoPath': 'users/u1/tryon/p.jpg',
    'tryOnPhotoUrl': 'https://example.com/p.jpg',
    'tryOnCutoutUrl': 'https://example.com/p.png',
    'tryOnCutoutFor': 'users/u1/tryon/p.jpg',
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeToday extends ChangeNotifier implements TodayController {
  @override
  String get occasion => 'casual';

  @override
  TodayResult? get current => null;

  @override
  bool get loading => false;

  @override
  String? get error => 'offline';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

WardrobeItem _item(String id, String name, String category) => WardrobeItem.fromDoc(id, {
  'name': name,
  'category': category,
  'imagePath': 'users/u1/wardrobe/$id.jpg',
  'imageUrl': 'https://example.com/$id.jpg',
  'cutoutUrl': 'https://example.com/$id.png',
  'cutoutFor': 'users/u1/wardrobe/$id.jpg',
});

void main() {
  testWidgets('dress up: stage + shelf fit the phone, mix & match fills the outfit rail', (tester) async {
    // The tab body inside the iPhone frame (below the app bar, above the nav bar).
    tester.view.physicalSize = const Size(393, 628);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final items = [
      _item('t1', 'Cream knit', 'tops'),
      _item('t2', 'Striped tee', 'tops'),
      _item('b1', 'Wide-leg jeans', 'trousers'),
      _item('d1', 'Slip dress', 'dresses'),
      _item('s1', 'White trainers', 'shoes'),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuth()),
          ChangeNotifierProvider<TodayController>(create: (_) => _FakeToday()),
        ],
        child: MaterialApp(
          home: Scaffold(body: DressUpScreen(debugItems: items)),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Try a new look'), findsOneWidget);
    expect(find.text('See it on me'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Cream knit'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('See it on me'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Bottoms'));
    await tester.pump();
    await tester.tap(find.textContaining('Bottoms'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel('Wide-leg jeans'));
    await tester.ensureVisible(find.textContaining('Shoes'));
    await tester.pump();
    await tester.tap(find.textContaining('Shoes'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel('White trainers'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.close_rounded), findsNWidgets(3));

    // A dress replaces the top and bottoms.
    await tester.ensureVisible(find.textContaining('Dresses'));
    await tester.pump();
    await tester.tap(find.textContaining('Dresses'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel('Slip dress'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));

    await tester.tap(find.text('Styled'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Surprise me'), findsOneWidget);
    await tester.tap(find.text('Surprise me'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.close_rounded), findsWidgets);

    expect(tester.takeException(), isNull);

    // Let Pip's animations and any delayed work finish so no timers outlive the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
