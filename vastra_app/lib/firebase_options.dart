// File generated manually for Vastra / mcurio-main.
// Run `flutterfire configure` later to refresh platform-specific app IDs if needed.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDfbVd5FZyGvibG1xC1oxAI7ATqjUA4Hbs',
    appId: '1:328325046668:web:83c1e9c44fef26ffacb6a9',
    messagingSenderId: '328325046668',
    projectId: 'mcurio-main',
    authDomain: 'mcurio-main.firebaseapp.com',
    databaseURL: 'https://mcurio-main-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'mcurio-main.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAc3h5YTqmwwY-srrwLcUpOd2IpjA5DUv0',
    appId: '1:328325046668:android:917da63acd8c07c8acb6a9',
    messagingSenderId: '328325046668',
    projectId: 'mcurio-main',
    databaseURL: 'https://mcurio-main-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'mcurio-main.firebasestorage.app',
  );

  // Same project; replace with native app IDs from Firebase Console if auth fails on device.

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDK4ihQESGlhDmxr2pGdcPYO3tJk_N57VI',
    appId: '1:328325046668:ios:a74cfb4685684fffacb6a9',
    messagingSenderId: '328325046668',
    projectId: 'mcurio-main',
    databaseURL: 'https://mcurio-main-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'mcurio-main.firebasestorage.app',
    iosClientId: '328325046668-752qvvc0ca9kdaif84pds4ht2nq05slv.apps.googleusercontent.com',
    iosBundleId: 'com.vastra.vastraApp',
  );
}
