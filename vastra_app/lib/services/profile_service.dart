import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';
import '../models/picked_photo.dart';
import 'functions_api.dart';
import 'wardrobe_service.dart';

class ProfileService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) => _db.collection('users').doc(uid);

  Future<UserProfile> ensureProfile({String? displayName}) async {
    final user = FirebaseAuth.instance.currentUser!;
    final ref = _ref(user.uid);
    final snap = await ref.get();
    if (snap.exists) return UserProfile.fromMap(user.uid, snap.data()!);

    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': displayName ?? user.displayName ?? '',
      'createdAt': now,
      'updatedAt': now,
      'onboardingComplete': false,
      'onboardingStep': 0,
      'consentAiProcessing': false,
      'createdAtServer': FieldValue.serverTimestamp(),
    };
    await ref.set(data);
    return UserProfile.fromMap(user.uid, data);
  }

  Stream<UserProfile?> watchProfile(String uid) =>
      _ref(uid).snapshots().map((snap) => snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null);

  Future<void> update(String uid, Map<String, dynamic> patch) {
    return _ref(uid).set({...patch, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true));
  }

  Future<void> uploadTryOnPhoto({required String uid, required PickedPhoto photo}) async {
    final path = 'users/$uid/tryon/person-${DateTime.now().millisecondsSinceEpoch}.${photo.extension}';
    final ref = _storage.ref(path);
    await ref.putData(photo.bytes, SettableMetadata(contentType: photo.contentType, cacheControl: immutableCache));
    final url = await ref.getDownloadURL();
    await update(uid, {'tryOnPhotoPath': path, 'tryOnPhotoUrl': url});
    unawaited(const FunctionsApi().cutoutPortrait().catchError((_) {}));
  }
}
