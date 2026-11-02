import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Tracks the browser's online/offline events.
ValueListenable<bool> createOnlineListenable() {
  final online = ValueNotifier<bool>(web.window.navigator.onLine);
  web.window.addEventListener('online', ((web.Event _) => online.value = true).toJS);
  web.window.addEventListener('offline', ((web.Event _) => online.value = false).toJS);
  return online;
}
