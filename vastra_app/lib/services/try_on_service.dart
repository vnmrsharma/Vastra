import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class TryOnService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('tryOnJobs');

  /// Every successful try-on is kept automatically — this is the Looks gallery.
  Stream<List<TryOnJob>> watchLooks(String uid) =>
      _col(uid)
          .orderBy('createdAt', descending: true)
          .limit(120)
          .snapshots()
          .map((snap) => snap.docs.map((d) => TryOnJob.fromDoc(d.id, d.data())).where((job) => job.isSuccess).toList());

  Future<void> setFavourite(String uid, String jobId, bool value) => _col(uid).doc(jobId).update({'favourite': value});

  Future<void> delete(String uid, String jobId) => _col(uid).doc(jobId).delete();
}
