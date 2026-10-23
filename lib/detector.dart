import 'dart:typed_data';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'voting.dart';

/// Letakkan model hasil ekspor di assets/models/model.tflite
const String kModelPath = 'assets/models/model.tflite';

/// Ambang confidence untuk voting (samakan dengan Bab III).
const double kConfThreshold = 0.25;

class DetectionOutput {
  final List<DetItem> items;
  final Uint8List? annotated;
  final double pluginMs;
  final int endToEndMs;
  const DetectionOutput(this.items, this.annotated, this.pluginMs, this.endToEndMs);
}

class CapsiDetector {
  YOLO? _yolo;

  Future<void> init() async {
    _yolo = YOLO(modelPath: kModelPath, task: YOLOTask.detect);
    await _yolo!.loadModel();
  }

  /// TODO prapemrosesan (bilateral filter + CLAHE + letterbox) agar sama dengan
  /// data latih. Versi awal ini meneruskan citra apa adanya.
  Future<Uint8List> preprocess(Uint8List bytes) async => bytes;

  Future<DetectionOutput> run(Uint8List original) async {
    final sw = Stopwatch()..start();
    final input = await preprocess(original);
    final dynamic raw = await _yolo!.predict(input);
    final YOLODetectionResults res = raw is YOLODetectionResults
        ? raw
        : YOLODetectionResults.fromMap(Map<dynamic, dynamic>.from(raw as Map));
    sw.stop();
    final items = res.detections
        .where((r) => r.confidence >= kConfThreshold)
        .map((r) => DetItem(r.className, r.confidence))
        .toList();
    return DetectionOutput(items, res.annotatedImage, res.processingTimeMs, sw.elapsedMilliseconds);
  }
}
