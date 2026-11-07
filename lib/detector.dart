import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'voting.dart';

/// Letakkan model hasil ekspor di assets/models/model.tflite
const String kModelPath = 'assets/models/model.tflite';

/// Ambang confidence untuk voting dan tampilan (samakan dengan Bab III).
const double kConfThreshold = 0.25;

/// Saklar prapemrosesan. Isi false bila ingin membandingkan hasil tanpa
/// prapemrosesan, atau bila OpenCV bermasalah di perangkat.
const bool kUsePreprocess = true;

/// Prapemrosesan sama dengan data latih (Bab 3.6.2):
/// bilateral filter (d=9, sigmaColor=75, sigmaSpace=75)
/// -> CLAHE pada kanal L ruang warna LAB (clipLimit=2.0, tile 8x8).
/// Letterbox ditangani pustaka inferensi. Keluaran JPEG (sama dengan
/// format keluaran skrip prapemrosesan data latih).
///
/// Fungsi ini sinkron dan berat, jadi hanya dipanggil dari isolate.
Uint8List _preprocessSync(Uint8List bytes) {
  final src = cv.imdecode(bytes, cv.IMREAD_COLOR); // BGR
  if (src.isEmpty) {
    src.dispose();
    throw StateError('Citra tidak dapat didekode oleh OpenCV');
  }
  final filtered = cv.bilateralFilter(src, 9, 75, 75);
  src.dispose();

  final lab = cv.cvtColor(filtered, cv.COLOR_BGR2Lab);
  filtered.dispose();

  final channels = cv.split(lab);
  lab.dispose();

  final clahe = cv.CLAHE(2.0, (8, 8));
  final lEq = clahe.apply(channels[0]);
  clahe.dispose();

  final merged = cv.merge(cv.VecMat.fromList([lEq, channels[1], channels[2]]));
  lEq.dispose();
  channels.dispose();

  final bgr = cv.cvtColor(merged, cv.COLOR_Lab2BGR);
  merged.dispose();

  // Versi paket berbeda: imencode bisa mengembalikan Uint8List atau (bool, Uint8List).
  final dynamic enc = cv.imencode('.jpg', bgr); // kualitas bawaan OpenCV = 95
  bgr.dispose();
  final Uint8List out = enc is Uint8List ? enc : (enc as (bool, Uint8List)).$2;
  return out;
}

/// Dijalankan di isolate terpisah agar UI (animasi) tidak tersendat.
/// Sengaja fungsi top-level supaya closure tidak membawa objek lain.
Future<Uint8List> preprocessImage(Uint8List bytes) =>
    Isolate.run(() => _preprocessSync(bytes));

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
  final int prepMs; // bagian praproses saja
  final bool prepOk; // false bila praproses gagal dan dilewati
  const DetectionOutput(
    this.boxes,
    this.pluginMs,
    this.detectMs, {
    this.prepMs = 0,
    this.prepOk = true,
  });

  List<DetItem> get items => boxes.map((b) => DetItem(b.className, b.confidence)).toList();
}

class CapsiDetector {
  YOLO? _yolo;
  bool _prepOk = true;

  Future<void> init() async {
    _yolo = YOLO(modelPath: kModelPath, task: YOLOTask.detect);
    await _yolo!.loadModel();
  }

  /// Bila prapemrosesan gagal, citra asli diteruskan agar aplikasi tetap
  /// berjalan, dan statusnya ditandai di hasil.
  Future<Uint8List> preprocess(Uint8List bytes) async {
    if (!kUsePreprocess) return bytes;
    try {
      final out = await preprocessImage(bytes);
      _prepOk = true;
      return out;
    } catch (_) {
      _prepOk = false;
      return bytes;
    }
  }

  Rect _toRect(YOLOResult r, double w, double h) {
    final n = r.normalizedBox;
    if (n.width > 0 && n.height > 0 && n.right <= 1.5 && n.bottom <= 1.5) {
      return Rect.fromLTRB(n.left * w, n.top * h, n.right * w, n.bottom * h);
    }
    return r.boundingBox;
  }

  Future<DetectionOutput> run(
    Uint8List imageBytes,
    int width,
    int height, {
    void Function(String stage)? onStage,
  }) async {
    final sw = Stopwatch()..start();
    onStage?.call('Prapemrosesan citra');
    final input = await preprocess(imageBytes);
    final prepMs = sw.elapsedMilliseconds;

    onStage?.call('Mendeteksi organ');
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
    return DetectionOutput(
      boxes,
      res.processingTimeMs,
      sw.elapsedMilliseconds,
      prepMs: prepMs,
      prepOk: _prepOk || !kUsePreprocess,
    );
  }
}
