import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// A photo held in memory so the same code works on iOS, Android and the web.
class PickedPhoto {
  PickedPhoto(this.bytes);

  final Uint8List bytes;

  bool get isPng => bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;

  String get contentType => isPng ? 'image/png' : 'image/jpeg';
  String get extension => isPng ? 'png' : 'jpg';

  static Future<PickedPhoto> fromXFile(XFile file) async => PickedPhoto(await file.readAsBytes());
}
