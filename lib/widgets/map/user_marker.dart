import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:async';

class UserMarker {
  static Future<BitmapDescriptor> createCustomMarker({
    required String name,
    String? imageUrl,
    Color backgroundColor = const Color(0xFF2196F3),
    Color textColor = Colors.white,
  }) async {
    final recoder = ui.PictureRecorder();
    final canvas = ui.Canvas(recoder);
    final size = Size(80, 80);
    
    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 + 2), 30, shadowPaint);
    
    // Draw background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 28, backgroundPaint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 28, borderPaint);
    
    // Draw text or image
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Logic for using image would go here
      // This requires more complex image loading and composition
      // For simplicity, we'll fall back to using the first letter instead
      _drawText(canvas, size, name.substring(0, 1).toUpperCase(), textColor);
    } else {
      _drawText(canvas, size, name.substring(0, 1).toUpperCase(), textColor);
    }
    
    // Convert canvas to image
    final img = await recoder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    
    if (data == null) {
      throw 'Could not generate marker image';
    }
    
    return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
  }
  
  static void _drawText(
    ui.Canvas canvas,
    Size size,
    String text,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height / 2 - textPainter.height / 2,
      ),
    );
  }
  
  static Future<BitmapDescriptor> createDefaultMarker() async {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }
}