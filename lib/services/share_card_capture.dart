import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

/// Bir widget'ı ekran dışında çizip PNG dosyası olarak kaydeder.
/// Paylaşım için kullanılır; hata olursa null döner.
class ShareCardCapture {
  static Future<String?> capture(
    BuildContext context,
    Widget card, {
    required String fileName,
    double width = 360,
    double height = 420,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -width * 3,
        top: 0,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: width, height: height, child: card),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
      if (bytes == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('Share card capture error: $e');
      return null;
    } finally {
      entry.remove();
    }
  }
}
