import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/functions_api.dart';
import '../services/wardrobe_service.dart';

class TodayResult {
  TodayResult({required this.weather, required this.suggestions, this.note, required this.at});

  final WeatherSnapshot? weather;
  final List<OutfitSuggestion> suggestions;
  final String? note;
  final DateTime at;
}

/// Keeps today's looks per occasion so moving between tabs is instant, and opens from the copy
/// saved for today (users/{uid}/dailyLooks) before asking the stylist for fresh ones.
class TodayController extends ChangeNotifier {
  static const _freshFor = Duration(hours: 3);

  final _api = const FunctionsApi();
  final Map<String, TodayResult> _cache = {};

  String occasion = 'casual';
  bool loading = false;
  String? error;
  String? _uid;
  bool _closetChanged = false;

  TodayResult? get current => _cache[occasion];

  void bindUser(String? uid, {String? defaultOccasion}) {
    if (uid == _uid) return;
    _uid = uid;
    _cache.clear();
    error = null;
    if (defaultOccasion != null && occasions.contains(defaultOccasion)) {
      occasion = defaultOccasion;
    }
  }

  void selectOccasion(String value) {
    if (value == occasion) return;
    occasion = value;
    error = null;
    notifyListeners();
    load();
  }

  /// Drops cached looks after the closet or preferences change; Today reloads on next view.
  void invalidate() {
    _cache.clear();
    _closetChanged = true;
    error = null;
    notifyListeners();
  }

  Future<TodayResult?> _readSaved(String uid, String forOccasion) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailyLooks')
        .doc('${todayKey(DateTime.now())}_$forOccasion');
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await ref.get(const GetOptions(source: Source.cache));
    } catch (_) {}
    if (snap == null || !snap.exists) {
      try {
        snap = await ref.get().timeout(const Duration(seconds: 4));
      } catch (_) {
        return null;
      }
    }
    final data = snap.data();
    if (data == null) return null;
    final parsed = FunctionsApi.parseToday(data);
    if (parsed.suggestions.isEmpty) return null;
    return TodayResult(
      weather: parsed.weather,
      suggestions: parsed.suggestions,
      note: parsed.note,
      at: DateTime.fromMillisecondsSinceEpoch((data['createdAt'] as num?)?.toInt() ?? 0),
    );
  }

  Future<void> load({bool force = false}) async {
    final requested = occasion;
    final cached = _cache[requested];
    final fresh = cached != null && DateTime.now().difference(cached.at) < _freshFor;
    if (loading || (fresh && !force)) return;

    loading = true;
    error = null;
    notifyListeners();

    final uid = _uid;
    if (!force && !_closetChanged && cached == null && uid != null) {
      final saved = await _readSaved(uid, requested);
      if (saved != null) {
        _cache[requested] = saved;
        if (DateTime.now().difference(saved.at) < _freshFor) {
          loading = false;
          notifyListeners();
          return;
        }
        notifyListeners();
      }
    }

    try {
      final result = await _api.dressMeToday(occasion: requested, day: todayKey(DateTime.now()));
      _cache[requested] = TodayResult(
        weather: result.weather,
        suggestions: result.suggestions,
        note: result.note,
        at: DateTime.now(),
      );
      _closetChanged = false;
    } catch (e) {
      // Keep showing saved looks if a refresh fails; only surface the error when there's nothing to show.
      if (requested == occasion && _cache[requested] == null) error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
