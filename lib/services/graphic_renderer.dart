import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Saves whatever is inside a [RepaintBoundary] as a PNG file, and other
/// files the app shares.
///
/// The audit graphic is laid out at 1080×1350 logical pixels, so a
/// pixel ratio of 1 gives a full-size Instagram/WhatsApp image.
class GraphicRenderer {
  Future<Directory> _dir(String name) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/$name');
    await dir.create(recursive: true);
    return dir;
  }

  static String _safe(String name) {
    final s = name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();
    return s.isEmpty ? 'client' : (s.length > 40 ? s.substring(0, 40) : s);
  }

  Future<String> renderToFile(GlobalKey boundaryKey, String name) async {
    await WidgetsBinding.instance.endOfFrame;
    final context = boundaryKey.currentContext;
    if (context == null) throw StateError('The graphic is not on screen yet.');
    final boundary = context.findRenderObject() as RenderRepaintBoundary;

    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Could not create the image.');

    final dir = await _dir('graphics');
    // Remove old renders so the cache doesn't grow. A fresh file name each
    // time stops other apps from reusing a stale copy.
    for (final old in dir.listSync().whereType<File>()) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/audit_${_safe(name)}_$stamp.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file.path;
  }

  /// Writes text (e.g. a CSV export) to a shareable file.
  Future<String> writeExport(String fileName, String content) async {
    final dir = await _dir('exports');
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, flush: true);
    return file.path;
  }
}
