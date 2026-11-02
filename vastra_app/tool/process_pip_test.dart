// Prepares Pip artwork for the app:
//  • trims transparent margins and downsizes the YouCam cutouts in assets/pip/
//  • trims the Pip + Vastra logo into assets/brand/logo.png
//  • builds the full-bleed app icon (assets/icon/icon.png) and maskable icon from Pip/Icon.png
// Run: flutter test tool/process_pip_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _maxSide = 640;

Future<ui.Image> _load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<void> _save(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<Rect> _alphaBounds(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final px = data.buffer.asUint8List();
  var minX = image.width, minY = image.height, maxX = 0, maxY = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (px[(y * image.width + x) * 4 + 3] > 10) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX + 1.0, maxY + 1.0);
}

Future<ui.Image> _render(int w, int h, void Function(ui.Canvas canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  return recorder.endRecording().toImage(w, h);
}

Future<void> _trimAndResize(String input, String output, {int maxSide = _maxSide, double pad = 0.03}) async {
  final image = await _load(input);
  final bounds = await _alphaBounds(image);
  final p = math.max(bounds.width, bounds.height) * pad;
  final src = Rect.fromLTRB(
    math.max(0, bounds.left - p),
    math.max(0, bounds.top - p),
    math.min(image.width.toDouble(), bounds.right + p),
    math.min(image.height.toDouble(), bounds.bottom + p),
  );
  final scale = math.min(1.0, maxSide / math.max(src.width, src.height));
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();
  final out = await _render(w, h, (canvas) {
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  });
  await _save(out, output);
}

Future<Color> _sample(ui.Image image, List<Offset> points) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final px = data.buffer.asUint8List();
  var r = 0, g = 0, b = 0;
  for (final pt in points) {
    final i = (pt.dy.round() * image.width + pt.dx.round()) * 4;
    r += px[i];
    g += px[i + 1];
    b += px[i + 2];
  }
  final n = points.length;
  return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
}

Future<void> _icon(String input, String output, {required double scale, int size = 1024}) async {
  final art = await _load(input);
  final w = art.width.toDouble();
  final h = art.height.toDouble();
  // Fill colour taken from inside the artwork's own rounded square, so the edges blend.
  final fill = await _sample(art, [
    Offset(w * 0.14, h * 0.5),
    Offset(w * 0.86, h * 0.5),
    Offset(w * 0.5, h * 0.12),
    Offset(w * 0.5, h * 0.9),
  ]);
  final image = await _render(size, size, (canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), ui.Paint()..color = fill);
    final drawn = size * scale;
    final offset = (size - drawn) / 2;
    canvas.drawImageRect(
      art,
      Rect.fromLTWH(0, 0, w, h),
      Rect.fromLTWH(offset, offset, drawn, drawn),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  });
  await _save(image, output);
}

void main() {
  test('process Pip artwork', () async {
    final pipDir = Directory('assets/pip');
    for (final file in pipDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
      final bytes = file.lengthSync();
      if (bytes < 900 * 1024) continue; // already processed
      await _trimAndResize(file.path, file.path);
    }

    await _trimAndResize('../Pip/Logo.png', 'assets/brand/logo.png', maxSide: 900, pad: 0.02);

    // iOS/Android/web icon: artwork scaled up so its rounded square bleeds off the edges;
    // the OS applies its own corner mask.
    await _icon('../Pip/Icon.png', 'assets/icon/icon.png', scale: 1.25);
    // Maskable (circle-cropped) icon: the artwork's square sits fully inside the safe zone.
    await _icon('../Pip/Icon.png', 'assets/icon/icon_maskable.png', scale: 1.0);
    expect(File('assets/icon/icon.png').existsSync(), isTrue);
  });
}

// Keeps the analyzer happy about the typed_data import on all SDKs.
// ignore: unused_element
Uint8List _unused() => Uint8List(0);
