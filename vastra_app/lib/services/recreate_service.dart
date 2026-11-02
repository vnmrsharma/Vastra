import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class RecreateService {
  final _db = FirebaseFirestore.instance;

  /// Recent "Recreate a look" results, newest first.
  Stream<List<RecreateResult>> watchRecent(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('inspirations')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (snap) => snap.docs
            .where((d) => d.data()['kind'] == 'recreate')
            .map((d) => RecreateResult.fromMap(d.id, d.data()))
            .toList(),
      );

  Future<void> delete(String uid, String id) =>
      _db.collection('users').doc(uid).collection('inspirations').doc(id).delete();
}
