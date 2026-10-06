import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Saves whatever is inside a [RepaintBoundary] as a PNG file.
///
/// The audit graphic is laid out at 1080×1350 logical pixels, so a
/// pixel ratio of 1 gives a full-size Instagram/WhatsApp image.
class GraphicRenderer {
  Future<String> renderToFile(GlobalKey boundaryKey, String name) async {
    await WidgetsBinding.instance.endOfFrame;
    final context = boundaryKey.currentContext;
    if (context == null) throw StateError('The graphic is not on screen yet.');
    final boundary = context.findRenderObject() as RenderRepaintBoundary;

    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Could not create the image.');

    final dir = Directory('${(await getTemporaryDirectory()).path}/graphics');
    await dir.create(recursive: true);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();
    final file = File('${dir.path}/audit_${safe.isEmpty ? 'client' : safe}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file.path;
  }
}
