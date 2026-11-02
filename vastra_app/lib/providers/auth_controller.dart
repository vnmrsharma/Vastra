import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/profile_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({FirebaseAuth? auth, ProfileService? profileService})
    : _auth = auth ?? FirebaseAuth.instance,
      profiles = profileService ?? ProfileService() {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  final FirebaseAuth _auth;
  final ProfileService profiles;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserProfile?>? _profileSub;

  User? _user;
  UserProfile? _profile;
  bool _busy = false;
  bool _initializing = true;

  User? get user => _user;
  String? get uid => _user?.uid;
  UserProfile? get profile => _profile;
  bool get busy => _busy;
  bool get initializing => _initializing;

  /// Signed in, but the profile (and so whether onboarding is done) isn't known yet.
  bool get profileLoading => _profileLoading;
  bool _profileLoading = false;
  bool get isSignedIn => _user != null;
  bool get onboardingComplete => _profile?.onboardingComplete == true;

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    await _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      _profile = null;
      _initializing = false;
      notifyListeners();
      return;
    }

    _profileLoading = true;
    try {
      _profile = await profiles.ensureProfile();
      _profileSub = profiles.watchProfile(user.uid).listen(
        (p) {
          if (p == null) return;
          _profile = p;
          notifyListeners();
        },
        // Fires with permission-denied once the user signs out or deletes their account.
        onError: (Object _) {},
      );
    } catch (e) {
      debugPrint('Profile load failed: $e');
    }
    _profileLoading = false;
    _initializing = false;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> patch) async {
    final id = uid;
    if (id == null) return;
    await profiles.update(id, patch);
  }

  Future<void> signUp({required String email, required String password, required String displayName}) async {
    await _run(() async {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user!.updateDisplayName(displayName.trim());
      await profiles.ensureProfile(displayName: displayName.trim());
      await profiles.update(cred.user!.uid, {'displayName': displayName.trim(), 'consentAiProcessing': true});
    });
  }

  Future<void> signIn({required String email, required String password}) {
    return _run(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
