import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'detector.dart';
import 'ui.dart';

class NormalizedImage {
  final Uint8List png;
  final int width;
  final int height;
  const NormalizedImage(this.png, this.width, this.height);
}

double _c(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Membaca citra (orientasi EXIF diterapkan oleh Flutter), membatasi sisi
/// terpanjang, lalu menyimpannya sebagai PNG agar orientasi seragam untuk
/// model dan tampilan.
Future<NormalizedImage> normalizeImage(Uint8List bytes, {int maxSide = 1280}) async {
  ui.Codec codec = await ui.instantiateImageCodec(bytes);
  ui.FrameInfo frame = await codec.getNextFrame();
  ui.Image image = frame.image;
  if (image.width > maxSide || image.height > maxSide) {
    final bool landscape = image.width >= image.height;
    image.dispose();
    codec.dispose();
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: landscape ? maxSide : null,
      targetHeight: landscape ? null : maxSide,
    );
    frame = await codec.getNextFrame();
    image = frame.image;
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final result = NormalizedImage(data!.buffer.asUint8List(), image.width, image.height);
  image.dispose();
  codec.dispose();
  return result;
}

/// Menggambar kotak hijau dan label "Buah Rawit 95 %" di atas citra.
Future<Uint8List> renderAnnotated(Uint8List png, List<DetBox> boxes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ui.Image image = frame.image;
  final double w = image.width.toDouble();
  final double h = image.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  canvas.drawImage(image, Offset.zero, Paint());

  final double stroke = _c(w / 220, 2, 8);
  final double fontSize = _c(w / 30, 14, 40);
  final boxPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..color = kBoxGreen;
  final fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = kBoxGreen;

  for (final b in boxes) {
    final Rect r = Rect.fromLTRB(
      _c(b.rect.left, 0, w),
      _c(b.rect.top, 0, h),
      _c(b.rect.right, 0, w),
      _c(b.rect.bottom, 0, h),
    );
    canvas.drawRect(r, boxPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: b.label,
        style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double padX = fontSize * 0.35;
    final double padY = fontSize * 0.2;
    final double lw = tp.width + padX * 2;
    final double lh = tp.height + padY * 2;
    double top = r.top - lh;
    if (top < 0) top = r.top;
    double left = r.left;
    if (left + lw > w) left = _c(w - lw, 0, w);
    canvas.drawRect(Rect.fromLTWH(left, top, lw, lh), fillPaint);
    tp.paint(canvas, Offset(left + padX, top + padY));
  }

  final ui.Image out = await recorder.endRecording().toImage(image.width, image.height);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  image.dispose();
  out.dispose();
  codec.dispose();
  return bytes;
}
