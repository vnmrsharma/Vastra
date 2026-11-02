import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

class FunctionsApi {
  const FunctionsApi({this.baseUrl = 'https://europe-west1-mcurio-main.cloudfunctions.net'});

  final String baseUrl;

  /// Each function's direct Cloud Run host. Some networks block *.cloudfunctions.net, so the app calls
  /// these first and falls back to [baseUrl], remembering whichever answered.
  static const _directHostSuffix = '-u2ibcbbb7a-ew.a.run.app';
  static bool _preferDirect = true;

  Uri _uri(String path, {required bool direct}) =>
      direct ? Uri.parse('https://${path.substring(1).toLowerCase()}$_directHostSuffix') : Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 90),
    int retries = 0,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _postOnce(path, body, timeout);
      } on _RetryableError catch (e) {
        if (attempt >= retries) throw Exception(e.message);
        await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }
  }

  Future<Map<String, dynamic>> _postOnce(String path, Map<String, dynamic> body, Duration timeout) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please sign in again');
    final token = await user.getIdToken();

    http.Response? res;
    for (final direct in _preferDirect ? const [true, false] : const [false, true]) {
      try {
        res = await http
            .post(
              _uri(path, direct: direct),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(timeout);
        _preferDirect = direct;
        break;
      } on TimeoutException {
        // The request may still be running server-side, so don't resend it to the other host.
        throw const _RetryableError('That took longer than usual — try again in a moment.');
      } catch (_) {
        continue;
      }
    }
    if (res == null) throw const _RetryableError('Connection hiccup — check your internet and try again.');

    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(res.body.isEmpty ? '{}' : res.body) as Map);
    } catch (_) {
      data = {};
    }
    if (res.statusCode == 429 || res.statusCode == 503 || res.statusCode == 504) {
      throw _RetryableError(data['error']?.toString() ?? 'Vastra’s stylist is waking up — try again in a moment.');
    }
    if (res.statusCode >= 400) {
      throw Exception(data['error']?.toString() ?? 'Something went wrong (${res.statusCode})');
    }
    return data;
  }

  Future<String> startTryOn({
    String? wardrobeItemId,
    String? garmentPath,
    String? garmentPreviewUrl,
    required String garmentCategory,
    required String title,
  }) async {
    final data = await _post('/startTryOn', {
      'wardrobeItemId': wardrobeItemId,
      'garmentPath': garmentPath,
      'garmentPreviewUrl': garmentPreviewUrl,
      'garmentCategory': garmentCategory,
      'title': title,
    });
    return data['jobId'] as String;
  }

  /// Polls until YouCam finishes. Returns the result URL or throws a friendly error.
  Future<String> waitForTryOn(String jobId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 150));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final data = await _post('/pollTryOn', {'jobId': jobId});
      final status = data['status'] as String? ?? 'processing';
      if (status == 'success' && data['resultUrl'] != null) return data['resultUrl'] as String;
      if (status == 'error') throw Exception(explainTryOnError(data['error'] as String?));
    }
    throw Exception('YouCam is taking longer than usual — check Looks in a minute.');
  }

  Future<void> tagGarment(String itemId) => _post('/tagGarment', {'itemId': itemId}, retries: 1);

  /// Gemini matches an outfit photo to the closest pieces in the user's closet.
  Future<RecreateResult> recreateLook({required String imagePath, required String imageUrl}) async {
    final data = await _post('/recreateLook', {'imagePath': imagePath, 'imageUrl': imageUrl});
    return RecreateResult.fromMap(data['id'] as String? ?? '', data);
  }

  /// YouCam background removal for a closet piece; the item doc updates live.
  Future<void> cutoutItem(String itemId) => _post('/cutoutImage', {'itemId': itemId}, retries: 1);

  /// YouCam background removal for the try-on portrait; the profile updates live.
  Future<void> cutoutPortrait() => _post('/cutoutImage', {'portrait': true});

  /// Puts a mix-and-match outfit on the user's portrait, one YouCam step per piece.
  Future<({String jobId, String resultUrl, String? cutoutUrl})> dressUp(List<String> itemIds, {String? title}) async {
    try {
      final data = await _post('/dressUp', {'itemIds': itemIds, 'title': title}, timeout: const Duration(minutes: 6));
      return (
        jobId: data['jobId'] as String,
        resultUrl: data['resultUrl'] as String,
        cutoutUrl: data['cutoutUrl'] as String?,
      );
    } on Exception catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (message.contains(' ') || message.contains('—')) rethrow;
      throw Exception(explainTryOnError(message));
    }
  }

  /// Permanently deletes the signed-in user's photos, data and account.
  Future<void> deleteAccount() => _post('/deleteAccount', {});

  Future<({WeatherSnapshot? weather, List<OutfitSuggestion> suggestions, String? note})> dressMeToday({
    required String occasion,
    String? city,
    String? day,
  }) async {
    final data = await _post('/dressMeToday', {'occasion': occasion, 'city': city, 'day': day}, retries: 1);
    return parseToday(data);
  }

  /// Parses a dressMeToday response (or the copy saved under users/{uid}/dailyLooks).
  static ({WeatherSnapshot? weather, List<OutfitSuggestion> suggestions, String? note}) parseToday(
    Map<String, dynamic> data,
  ) {
    final weather = data['weather'] is Map
        ? WeatherSnapshot.fromMap(Map<String, dynamic>.from(data['weather'] as Map))
        : null;

    final suggestions = (data['suggestions'] as List? ?? []).whereType<Map>().map((raw) {
      final s = Map<String, dynamic>.from(raw);
      final items = (s['items'] as List? ?? []).whereType<Map>().map((i) {
        return LookItem.fromMap(Map<String, dynamic>.from(i));
      }).toList();
      return OutfitSuggestion(
        title: s['title'] as String? ?? 'Today’s look',
        reason: s['reason'] as String? ?? '',
        items: items,
      );
    }).toList();

    return (
      weather: weather,
      suggestions: suggestions,
      note: data['note'] as String? ?? (weather == null ? data['weatherNote'] as String? : null),
    );
  }

  /// Approximate city from the network — no location permission needed.
  static Future<String?> detectCity() async {
    const sources = ['https://ipwho.is/', 'https://ipapi.co/json/'];
    for (final url in sources) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final city = data['city'] as String?;
        if (city != null && city.trim().isNotEmpty) return city.trim();
      } catch (_) {}
    }
    return null;
  }
}

/// Network failures and server hiccups (cold starts, overload) that are safe to retry.
class _RetryableError implements Exception {
  const _RetryableError(this.message);
  final String message;
}
