import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'detector.dart';
import 'history_page.dart';
import 'history_store.dart';
import 'image_utils.dart';
import 'ui.dart';
import 'voting.dart';

/// Menampung galat tak tertangani agar tampil di layar (bukan langsung menutup).
final ValueNotifier<String?> kAppError = ValueNotifier<String?>(null);

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      kAppError.value = 'Galat Flutter: ${details.exceptionAsString()}';
    };
    runApp(const CapsiScanApp());
  }, (error, stack) {
    kAppError.value = 'Galat tak tertangani: $error';
  });
}

class CapsiScanApp extends StatelessWidget {
  const CapsiScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CapsiScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kRed),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kRed,
      body: Center(
        child: Image.asset('assets/images/logo.png', width: 230),
      ),
    );
  }
}

class ScanResult {
  final DetectionOutput output;
  final VoteResult vote;
  final int totalMs;
  const ScanResult(this.output, this.vote, this.totalMs);

  int get count => output.boxes.length;

  double get avgConf => output.boxes.isEmpty
      ? 0
      : output.boxes.map((e) => e.confidence).reduce((a, b) => a + b) / output.boxes.length;

  String get organsSummary {
    final counts = <String, int>{};
    for (final b in output.boxes) {
      counts[b.className] = (counts[b.className] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    return counts.entries.map((e) => '${e.key} x${e.value}').join(', ');
  }

  String get pointsSummary {
    final s = vote.points.entries.map((e) => '${e.key} ${e.value}').join(', ');
    // Saat suara seri, tampilkan juga skor confidence yang dipakai tie-break.
    if (vote.note != null && vote.scores.isNotEmpty) {
      final sc = vote.scores.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key} ${e.value.toStringAsFixed(2)}')
          .join(', ');
      return '$s | Skor: $sc';
    }
    return s;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CapsiDetector _detector = CapsiDetector();
  final ImagePicker _picker = ImagePicker();

  /// Label tahap proses yang ditampilkan di atas animasi pemindaian.
  final ValueNotifier<String> _stage = ValueNotifier<String>('Menyiapkan gambar');

  bool _modelReady = false;
  bool _busy = false;
  bool _showHistory = false;
  bool _expanded = true;
  bool _saved = false;
  String? _error;
  Uint8List? _preview; // foto yang sedang diproses (untuk animasi)
  Uint8List? _annotated;
  ScanResult? _result;

  /// Tombol kembali muncul saat ada hasil, riwayat, atau galat di layar.
  bool get _canGoBack => !_busy && (_showHistory || _result != null || _error != null);

  @override
  void dispose() {
    _stage.dispose();
    super.dispose();
  }

  /// Model dimuat saat pemindaian pertama (bukan saat aplikasi dibuka),
  /// supaya aplikasi tetap bisa dibuka walaupun model bermasalah.
  Future<bool> _ensureModel() async {
    if (_modelReady) return true;
    try {
      await _detector.init();
      if (!mounted) return false;
      setState(() => _modelReady = true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _error = 'Gagal memuat model: $e');
      return false;
    }
  }

  Future<void> _scan(ImageSource source) async {
    if (_busy) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 95,
    );
    if (picked == null) return;
    final raw = await picked.readAsBytes();
    if (!mounted) return;

    _stage.value = _modelReady ? 'Menyiapkan gambar' : 'Memuat model';
    setState(() {
      _busy = true;
      _showHistory = false;
      _error = null;
      _saved = false;
      _annotated = null;
      _result = null;
      _preview = raw; // foto langsung tampil bersama animasi pemindaian
    });
    try {
      if (!await _ensureModel()) return;
      final sw = Stopwatch()..start();
      _stage.value = 'Menyiapkan gambar';
      final norm = await normalizeImage(raw);
      final out = await _detector.run(
        norm.png,
        norm.width,
        norm.height,
        onStage: (s) => _stage.value = s,
      );
      _stage.value = 'Menghitung voting';
      final vote = castVote(out.items);
      sw.stop();
      _stage.value = 'Menggambar hasil';
      final annotated = await renderAnnotated(norm.png, out.boxes);
      if (!mounted) return;
      setState(() {
        _annotated = annotated;
        _result = ScanResult(out, vote, sw.elapsedMilliseconds);
        _expanded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memproses gambar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _preview = null;
        });
      }
    }
  }

  Future<void> _save() async {
    final r = _result;
    final img = _annotated;
    if (r == null || img == null) return;
    await HistoryStore.add(
      imageBytes: img,
      jenis: r.vote.label,
      avgConf: r.avgConf,
      count: r.count,
      ms: r.totalMs,
      organs: r.organsSummary,
    );
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hasil disimpan ke riwayat.')),
    );
  }

  /// Kembali ke layar awal (dipakai tombol kembali, tombol back sistem,
  /// dan SCAN ULANG).
  void _reset() => setState(() {
        _showHistory = false;
        _annotated = null;
        _result = null;
        _error = null;
        _saved = false;
      });

  Widget _placeholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 200),
            const SizedBox(height: 16),
            const Text(
              'Ambil atau unggah gambar tanaman cabai untuk dideteksi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summarySheet(ScanResult r) {
    final pct = (r.avgConf * 100).round();
    final prep = r.output.prepOk
        ? 'prapro ${r.output.prepMs} ms'
        : 'prapro dilewati';
    return SheetPanel(
      title: 'Ringkasan Deteksi',
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GreyCard(
            child: Column(
              children: [
                Text(
                  r.vote.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: kSerif,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$kConfLabel : $pct %'),
                    const SizedBox(width: 24),
                    Text('Jumlah : ${r.count} Objek'),
                  ],
                ),
                if (r.vote.note != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    r.vote.note!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kRedDark,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Waktu proses ${r.totalMs} ms ($prep)  |  Suara: ${r.pointsSummary}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saved ? null : _save,
                  style: filledRed(),
                  child: Text(_saved ? 'TERSIMPAN' : 'SIMPAN'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  style: outlinedRed(),
                  child: const Text('SCAN ULANG'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultBody(ScanResult r, Uint8List img) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: Center(
              child: Image.memory(img, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideUpIn(child: _summarySheet(r)),
        ),
      ],
    );
  }

  /// Satu widget berkunci per tampilan; AnimatedSwitcher memudarkan
  /// perpindahan antartampilan (ringan: hanya cross-fade).
  Widget _content() {
    final r = _result;
    final img = _annotated;
    if (_showHistory) return const HistoryPage(key: ValueKey('history'));
    if (_busy && _preview != null) {
      return ScanningView(
        key: const ValueKey('scanning'),
        image: _preview!,
        stage: _stage,
      );
    }
    if (r != null && img != null) {
      return KeyedSubtree(key: const ValueKey('result'), child: _resultBody(r, img));
    }
    return KeyedSubtree(key: const ValueKey('placeholder'), child: _placeholder());
  }

  Widget _banner(String text, Color bg) => Container(
        width: double.infinity,
        color: bg,
        padding: const EdgeInsets.all(12),
        child: Text(text),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Tombol back sistem ikut kembali ke layar awal sebelum keluar aplikasi.
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canGoBack) _reset();
      },
      child: Scaffold(
        appBar: CapsiAppBar(onBack: _canGoBack ? _reset : null),
        body: Column(
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: kAppError,
              builder: (context, v, _) =>
                  v == null ? const SizedBox.shrink() : _banner(v, Colors.orange.shade100),
            ),
            if (_error != null) _banner(_error!, Colors.red.shade50),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, if (current != null) current],
                ),
                child: _content(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CapsiBottomBar(
          historyActive: _showHistory,
          onUpload: () => _scan(ImageSource.gallery),
          onCamera: () => _scan(ImageSource.camera),
          onHistory: () {
            if (!_busy) setState(() => _showHistory = true);
          },
        ),
      ),
    );
  }
}
