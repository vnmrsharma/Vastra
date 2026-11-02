import 'package:flutter/foundation.dart';

/// Native builds rely on Firestore's own offline handling; assume online.
ValueListenable<bool> createOnlineListenable() => ValueNotifier(true);
