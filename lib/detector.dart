import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'voting.dart';

/// Letakkan model hasil ekspor di assets/models/model.tflite
const String kModelPath = 'assets/models/model.tflite';

/// Ambang confidence untuk voting dan tampilan (samakan dengan Bab III).
const double kConfThreshold = 0.25;

class DetBox {
  final String className;
  final double confidence;
  final Rect rect; // koordinat piksel pada citra yang dikirim ke model
  const DetBox(this.className, this.confidence, this.rect);

  String get label => '${prettyClass(className)} ${(confidence * 100).round()} %';
}

class DetectionOutput {
  final List<DetBox> boxes;
  final double pluginMs;
  final int detectMs; // praproses + inferensi + pasca-proses di sisi Dart
  const DetectionOutput(this.boxes, this.pluginMs, this.detectMs);

  List<DetItem> get items => boxes.map((b) => DetItem(b.className, b.confidence)).toList();
}

class CapsiDetector {
  YOLO? _yolo;

  Future<void> init() async {
    _yolo = YOLO(modelPath: kModelPath, task: YOLOTask.detect);
    await _yolo!.loadModel();
  }

  /// TODO prapemrosesan (bilateral filter + CLAHE) agar sama dengan data latih.
  /// Versi ini meneruskan citra apa adanya.
  Future<Uint8List> preprocess(Uint8List bytes) async => bytes;

  Rect _toRect(YOLOResult r, double w, double h) {
    final n = r.normalizedBox;
    if (n.width > 0 && n.height > 0 && n.right <= 1.5 && n.bottom <= 1.5) {
      return Rect.fromLTRB(n.left * w, n.top * h, n.right * w, n.bottom * h);
    }
    return r.boundingBox;
  }

  Future<DetectionOutput> run(Uint8List imageBytes, int width, int height) async {
    final sw = Stopwatch()..start();
    final input = await preprocess(imageBytes);
    final dynamic raw = await _yolo!.predict(input);
    final YOLODetectionResults res = raw is YOLODetectionResults
        ? raw
        : YOLODetectionResults.fromMap(Map<dynamic, dynamic>.from(raw as Map));
    sw.stop();
    final boxes = <DetBox>[];
    for (final r in res.detections) {
      if (r.confidence < kConfThreshold) continue;
      boxes.add(DetBox(r.className, r.confidence, _toRect(r, width.toDouble(), height.toDouble())));
    }
    return DetectionOutput(boxes, res.processingTimeMs, sw.elapsedMilliseconds);
  }
}
