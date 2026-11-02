import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';
import '../models/picked_photo.dart';
import 'functions_api.dart';

class WardrobeService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _api = const FunctionsApi();

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('wardrobeItems');

  CollectionReference<Map<String, dynamic>> _wearLog(String uid) =>
      _db.collection('users').doc(uid).collection('wearLog');

  Stream<List<WardrobeItem>> watch(String uid) =>
      _col(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) => WardrobeItem.fromDoc(d.id, d.data())).toList());

  Future<({String path, String url})> uploadImage({
    required String uid,
    required PickedPhoto photo,
    String folder = 'wardrobe',
  }) async {
    final path = 'users/$uid/$folder/${DateTime.now().microsecondsSinceEpoch}.${photo.extension}';
    final ref = _storage.ref(path);
    await ref.putData(photo.bytes, SettableMetadata(contentType: photo.contentType, cacheControl: immutableCache));
    return (path: path, url: await ref.getDownloadURL());
  }

  /// Uploads a photo, creates the closet item straight away, and lets Gemini
  /// fill in name/category/colour in the background (the item updates live).
  Future<String> addFromPhoto({required String uid, required PickedPhoto photo}) async {
    final uploaded = await uploadImage(uid: uid, photo: photo);
    final now = DateTime.now().millisecondsSinceEpoch;
    final doc = await _col(uid).add({
      'userId': uid,
      'name': 'New piece',
      'category': 'tops',
      'colour': '',
      'pattern': null,
      'seasonTags': <String>[],
      'occasionTags': <String>[],
      'imagePath': uploaded.path,
      'imageUrl': uploaded.url,
      'tagging': true,
      'wearCount': 0,
      'lastWornAt': null,
      'youcamFileId': null,
      'createdAt': now,
      'updatedAt': now,
    });
    _api.tagGarment(doc.id).catchError((_) => _col(uid).doc(doc.id).update({'tagging': false}));
    _requestCutout(doc.id);
    return doc.id;
  }

  static final _cutoutRequested = <String>{};
  static final _cutoutQueue = <String>[];
  static int _cutoutsRunning = 0;

  /// YouCam removes the photo background so pieces look clean and consistent everywhere.
  void _requestCutout(String itemId) {
    if (!_cutoutRequested.add(itemId)) return;
    _cutoutQueue.add(itemId);
    _pumpCutouts();
  }

  void _pumpCutouts() {
    while (_cutoutsRunning < 3 && _cutoutQueue.isNotEmpty) {
      final id = _cutoutQueue.removeAt(0);
      _cutoutsRunning++;
      _api.cutoutItem(id).catchError((_) {}).whenComplete(() {
        _cutoutsRunning--;
        _pumpCutouts();
      });
    }
  }

  /// Backfills cutouts for pieces added before background removal existed.
  void ensureCutouts(List<WardrobeItem> items) {
    for (final item in items) {
      if (item.needsCutout) _requestCutout(item.id);
    }
  }

  Future<void> updateItem(String uid, String itemId, Map<String, dynamic> patch) {
    return _col(uid)
        .doc(itemId)
        .update({...patch, 'tagging': false, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> deleteItem(String uid, WardrobeItem item) async {
    await _col(uid).doc(item.id).delete();
    for (final path in [item.imagePath, item.cutoutPath, item.cutoutThumbPath]) {
      if (path == null || path.isEmpty) continue;
      try {
        await _storage.ref(path).delete();
      } catch (_) {}
    }
  }

  /// Records today's outfit: one log entry per day, and wear stats on each piece.
  Future<void> logOutfit({
    required String uid,
    required List<String> itemIds,
    required String title,
    required String occasion,
  }) async {
    final now = DateTime.now();
    final day = todayKey(now);
    final batch = _db.batch();
    batch.set(_wearLog(uid).doc(day), {
      'day': day,
      'title': title,
      'occasion': occasion,
      'itemIds': itemIds,
      'loggedAt': now.millisecondsSinceEpoch,
    });
    for (final id in itemIds) {
      batch.update(_col(uid).doc(id), {'wearCount': FieldValue.increment(1), 'lastWornAt': now.millisecondsSinceEpoch});
    }
    await batch.commit();
  }

  Future<void> clearToday(String uid) => _wearLog(uid).doc(todayKey(DateTime.now())).delete();

  Stream<WornToday?> watchToday(String uid) =>
      _wearLog(uid)
          .doc(todayKey(DateTime.now()))
          .snapshots()
          .map((snap) => snap.exists ? WornToday.fromMap(snap.data()!) : null);
}

String todayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Upload paths are unique, so browsers and phones can cache these images forever.
const immutableCache = 'public, max-age=31536000, immutable';
