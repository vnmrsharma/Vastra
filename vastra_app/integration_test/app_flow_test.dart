// End-to-end walkthrough against the live backend:
// signup → onboarding → Today (Gemini looks) → Wear today → YouCam try-on →
// Looks → Settings → delete account. Uses 2 YouCam units.
//
// Run: flutter test integration_test/app_flow_test.dart -d <simulator id>
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:vastra_app/main.dart' as app;
import 'package:vastra_app/models/picked_photo.dart';
import 'package:vastra_app/services/functions_api.dart';
import 'package:vastra_app/services/profile_service.dart';
import 'package:vastra_app/services/wardrobe_service.dart';
import 'package:vastra_app/widgets/vastra_widgets.dart';

const _person = 'https://plugins-media.makeupar.com/strapi/assets/clothes_03_cccd5d4803.jpeg';
const _garment = 'https://plugins-media.makeupar.com/strapi/assets/clothes_reference_full_body_01_5a000d999f.png';

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? label,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for ${label ?? finder}');
}

Future<void> tapText(WidgetTester tester, String text, {bool last = false}) async {
  final f = find.text(text);
  await pumpUntil(tester, f, label: '"$text"');
  await tester.ensureVisible(last ? f.last : f.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(last ? f.last : f.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> pause(WidgetTester tester, [int ms = 1800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<PickedPhoto> download(String url) async {
  final res = await http.get(Uri.parse(url));
  return PickedPhoto(Uint8List.fromList(res.bodyBytes));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Vastra full flow', (tester) async {
    final email = 'e2e-${Random().nextInt(1 << 30)}@vastra-test.dev';
    app.main();
    await pause(tester, 4000);
    // Remove leftovers from earlier test runs; never touch a real account.
    final existing = FirebaseAuth.instance.currentUser;
    if (existing != null) {
      if ((existing.email ?? '').endsWith('@vastra-test.dev')) {
        await const FunctionsApi().deleteAccount();
      }
      await FirebaseAuth.instance.signOut();
    }
    await pause(tester, 2000);

    try {
      // Welcome → signup
      await tapText(tester, 'Start styling');
      final signedInAs = FirebaseAuth.instance.currentUser;
      expect(signedInAs, isNull, reason: 'test must start signed out');
      await pumpUntil(tester, find.text('Create your wardrobe'));
      await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Ava');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'VastraTest-2026!');
      await tester.tap(find.byType(Checkbox));
      await pause(tester, 800);
      await tapText(tester, 'Continue');

      // Onboarding — seed portrait + two closet pieces like a user would by snapping photos.
      await pumpUntil(tester, find.text('Let’s go'), timeout: const Duration(seconds: 40));
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final person = await download(_person);
      final garment = await download(_garment);
      await ProfileService().uploadTryOnPhoto(uid: uid, photo: person);
      final wardrobe = WardrobeService();
      await wardrobe.addFromPhoto(uid: uid, photo: garment);
      await wardrobe.addFromPhoto(uid: uid, photo: person);
      await pause(tester);

      await tapText(tester, 'Let’s go');
      await pause(tester);
      await tapText(tester, 'London');
      await tapText(tester, 'Continue');
      await pause(tester);
      await tapText(tester, '🌼  Cottagecore');
      await tapText(tester, '🖤  Grunge');
      await pause(tester);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Work');
      await tapText(tester, 'Casual');
      await pause(tester);
      await tapText(tester, 'Continue');
      await pumpUntil(tester, find.text('Looks great'));
      await pause(tester);
      await tapText(tester, 'Looks great');
      await pumpUntil(tester, find.textContaining('of 3 pieces'), timeout: const Duration(seconds: 20));
      await pause(tester, 6000); // let Gemini name the pieces
      await tapText(tester, 'Continue');
      await pumpUntil(tester, find.text('You’re all set'));
      await pause(tester);
      await tapText(tester, 'Enter Vastra');

      // Today — Gemini looks with live weather
      await pumpUntil(tester, find.text('Today’s looks'), timeout: const Duration(seconds: 60), label: 'Today’s looks');
      await pause(tester, 2500);
      await tapText(tester, 'Wear today');
      await pause(tester, 3200); // Pip's celebration
      await tester.fling(find.byType(ListView).first, const Offset(0, 1600), 3000);
      await pause(tester, 800);
      await pumpUntil(tester, find.text('Today you’re wearing'), timeout: const Duration(seconds: 20));
      await pause(tester, 2500);

      // Closet
      await tapText(tester, 'Closet', last: true);
      await pumpUntil(tester, find.text('My closet'));
      await pause(tester, 2500);

      // Try-on from a closet piece (real YouCam call, skip with --dart-define=SKIP_TRYON=true)
      const skipTryOn = bool.fromEnvironment('SKIP_TRYON');
      await tapText(tester, 'Today', last: true);
      await pause(tester, 1000);
      final tryOnButton = find.widgetWithText(VastraPrimaryButton, 'Try on');
      await pumpUntil(tester, tryOnButton);
      await Scrollable.ensureVisible(tester.element(tryOnButton.first), alignment: 0.5);
      await pause(tester, 800);
      final navTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
      final buttonRect = tester.getRect(tryOnButton.first);
      debugPrint('LAYOUT nav top=$navTop button=$buttonRect screen=${tester.view.physicalSize / tester.view.devicePixelRatio}');
      expect(buttonRect.bottom <= navTop, isTrue, reason: 'Try on button must sit above the nav bar');
      await tester.tap(tryOnButton.first);
      final go = find.widgetWithText(VastraPrimaryButton, 'Try it on');
      await pumpUntil(tester, go, timeout: const Duration(seconds: 20), label: 'preselected piece on Try on');
      await pause(tester, 2000);
      await tester.ensureVisible(go);
      await pause(tester, 600);
      final scrollRect = tester.getRect(find.ancestor(of: go, matching: find.byType(Scrollable)).first);
      debugPrint('LAYOUT try-on scroll=$scrollRect button=${tester.getRect(go)} '
          'navTop=${tester.getTopLeft(find.byType(NavigationBar)).dy}');
      await Scrollable.ensureVisible(tester.element(go), alignment: 0.5);
      await pause(tester, 600);
      if (!skipTryOn) {
        await tester.tap(go);
        await pumpUntil(tester, find.text('Here you are ✨'), timeout: const Duration(seconds: 120), label: 'try-on result');
        await pause(tester, 4000);
      }

      // Looks
      await tapText(tester, 'Looks', last: true);
      await pumpUntil(tester, find.text('My looks'));
      await pause(tester, 3000);

      // Settings → delete account
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(CircleAvatar)).first);
      await pumpUntil(tester, find.text('ABOUT YOU'));
      await pause(tester, 2500);
      await tapText(tester, 'Delete account & photos');
      await tapText(tester, 'Delete forever');
      await pumpUntil(tester, find.text('Start styling'), timeout: const Duration(seconds: 60), label: 'back to welcome');
      expect(FirebaseAuth.instance.currentUser, isNull);
    } finally {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && (user.email ?? '').endsWith('@vastra-test.dev')) {
        await const FunctionsApi().deleteAccount();
        await FirebaseAuth.instance.signOut();
      }
    }
  });
}
