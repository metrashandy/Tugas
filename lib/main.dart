import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'detector.dart';
import 'history_page.dart';
import 'history_store.dart';
import 'voting.dart';

void main() => runApp(const CapsiScanApp());

const Color kRed = Color(0xFFD32F2F);

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
    return const Scaffold(
      backgroundColor: kRed,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.center_focus_strong, size: 96, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'CapsiScan',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 4),
            Text('Deteksi Tanaman Cabai', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class ScanResult {
  final DetectionOutput output;
  final VoteResult vote;
  const ScanResult(this.output, this.vote);

  double get avgConf => output.items.isEmpty
      ? 0
      : output.items.map((e) => e.confidence).reduce((a, b) => a + b) / output.items.length;

  String get organsSummary {
    final counts = <String, int>{};
    for (final it in output.items) {
      counts[it.className] = (counts[it.className] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    return counts.entries.map((e) => '${e.key} x${e.value}').join(', ');
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

  bool _modelReady = false;
  bool _busy = false;
  bool _showHistory = false;
  String? _error;
  Uint8List? _original;
  ScanResult? _result;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      await _detector.init();
      if (!mounted) return;
      setState(() => _modelReady = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat model: $e');
    }
  }

  Future<void> _scan(ImageSource source) async {
    if (!_modelReady) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return;
    setState(() {
      _busy = true;
      _showHistory = false;
      _error = null;
      _saved = false;
    });
    try {
      final bytes = await picked.readAsBytes();
      final out = await _detector.run(bytes);
      final vote = castVote(out.items);
      if (!mounted) return;
      setState(() {
        _original = bytes;
        _result = ScanResult(out, vote);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memproses gambar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final r = _result;
    final o = _original;
    if (r == null || o == null) return;
    await HistoryStore.add(
      imageBytes: r.output.annotated ?? o,
      jenis: r.vote.label,
      avgConf: r.avgConf,
      count: r.output.items.length,
      ms: r.output.endToEndMs,
      organs: r.organsSummary,
    );
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hasil disimpan ke riwayat.')),
    );
  }

  void _reset() => setState(() {
        _original = null;
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
            const Icon(Icons.center_focus_strong, size: 96, color: kRed),
            const SizedBox(height: 12),
            Text(
              _modelReady
                  ? 'Ambil atau unggah gambar tanaman cabai untuk dideteksi.'
                  : 'Memuat model...',
              textAlign: TextAlign.center,
            ),
            if (!_modelReady && _error == null) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultView() {
    final r = _result!;
    final shown = r.output.annotated ?? _original!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(shown)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ringkasan Deteksi', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(r.vote.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kRed)),
                const SizedBox(height: 8),
                Text('Rata-rata confidence: ${(r.avgConf * 100).toStringAsFixed(1)}%'),
                Text('Jumlah objek: ${r.output.items.length}'),
                Text('Organ terdeteksi: ${r.organsSummary}'),
                Text('Suara: ${r.vote.points.entries.map((e) => '${e.key} ${e.value}').join(', ')}'),
                Text('Waktu model: ${r.output.pluginMs.toStringAsFixed(0)} ms'),
                Text('Waktu end-to-end: ${r.output.endToEndMs} ms'),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _saved ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saved ? 'Tersimpan' : 'Simpan'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Ulang'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _body() {
    if (_showHistory) return const HistoryPage();
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
          ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: _result == null ? _placeholder() : _resultView()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        title: Text(_showHistory ? 'Riwayat' : 'CapsiScan'),
        centerTitle: true,
      ),
      body: _body(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: kRed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        currentIndex: _showHistory ? 2 : 0,
        onTap: (i) {
          if (i == 0) {
            _scan(ImageSource.gallery);
          } else if (i == 1) {
            _scan(ImageSource.camera);
          } else {
            setState(() => _showHistory = true);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Unggah Gambar'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Ambil Gambar'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
        ],
      ),
    );
  }
}
