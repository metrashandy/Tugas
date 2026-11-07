/// Logika voting multi-organ: setiap kelas organ unik yang terdeteksi memberi
/// satu suara bagi jenis cabai pada nama kelasnya (mis. "daun-rawit" -> rawit).
///
/// Bila suara seri, jenis diputuskan dari skor confidence (tie-break):
/// skor tiap jenis = jumlah confidence tertinggi dari setiap kelas organ unik
/// milik jenis itu. Jenis dengan skor tertinggi menang, sehingga setiap citra
/// yang punya deteksi selalu mendapat satu jenis.

const List<String> kJenis = ['rawit', 'besar', 'sala'];

/// true  = tiap NAMA KELAS unik memberi 1 suara (sama dengan kode Colab)
/// false = tiap KOTAK deteksi memberi 1 suara
const bool kVotePerUniqueClass = true;

/// true  = suara seri diputus dengan skor confidence (Bab 3.6.8 langkah 6)
/// false = suara seri dibiarkan seri/"Tidak Terdefinisi" (hanya untuk
///         membandingkan akurasi dengan dan tanpa tie-break)
const bool kTieBreakByConfidence = true;

class DetItem {
  final String className;
  final double confidence;
  const DetItem(this.className, this.confidence);
}

class VoteResult {
  final Map<String, int> points;
  final String? winner; // null jika seri tak terselesaikan atau tanpa deteksi
  final List<String> tied;
  final bool noDetection;

  /// Skor confidence per jenis (dipakai untuk tie-break).
  final Map<String, double> scores;

  /// true bila pemenang ditetapkan lewat tie-break confidence.
  final bool tieBroken;

  const VoteResult(
    this.points,
    this.winner,
    this.tied,
    this.noDetection, {
    this.scores = const {},
    this.tieBroken = false,
  });

  String get label {
    if (noDetection) return 'Tidak dapat ditentukan';
    if (winner == null) return 'Tidak Terdefinisi (${tied.map(_cap).join(' / ')})';
    return 'Cabai ${_cap(winner!)}';
  }

  /// Catatan singkat untuk pengguna pada kasus suara seri.
  String? get note {
    if (tieBroken) {
      return 'Suara seri, diputuskan dari total confidence. '
          'Disarankan ambil ulang dari sudut lain.';
    }
    if (!noDetection && winner == null) {
      return 'Suara seri. Ambil ulang gambar dari sudut yang berbeda.';
    }
    return null;
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

List<String> _parts(String cls) =>
    cls.toLowerCase().split(RegExp(r'[-_ ]')).where((e) => e.isNotEmpty).toList();

String? jenisOf(String cls) {
  final p = _parts(cls);
  if (p.length < 2) return null;
  return kJenis.contains(p.last) ? p.last : null;
}

String organOf(String cls) {
  final p = _parts(cls);
  return p.isEmpty ? cls : p.first;
}

VoteResult castVote(List<DetItem> items) {
  final points = {for (final j in kJenis) j: 0};
  final scores = {for (final j in kJenis) j: 0.0};

  if (kVotePerUniqueClass) {
    // Confidence tertinggi per kelas organ unik.
    final best = <String, double>{};
    for (final it in items) {
      final cur = best[it.className];
      if (cur == null || it.confidence > cur) best[it.className] = it.confidence;
    }
    for (final e in best.entries) {
      final j = jenisOf(e.key);
      if (j == null) continue;
      points[j] = points[j]! + 1;
      scores[j] = scores[j]! + e.value;
    }
  } else {
    for (final it in items) {
      final j = jenisOf(it.className);
      if (j == null) continue;
      points[j] = points[j]! + 1;
      scores[j] = scores[j]! + it.confidence;
    }
  }

  final maxPoint = points.values.fold<int>(0, (a, b) => a > b ? a : b);
  if (maxPoint == 0) {
    return VoteResult(points, null, const [], true, scores: scores);
  }
  final top = points.entries.where((e) => e.value == maxPoint).map((e) => e.key).toList();
  if (top.length == 1) {
    return VoteResult(points, top.first, const [], false, scores: scores);
  }

  // Suara seri.
  if (kTieBreakByConfidence) {
    final bestScore = top.map((j) => scores[j]!).reduce((a, b) => a > b ? a : b);
    // Skor persis sama hampir mustahil (confidence bernilai kontinu). Bila
    // tetap terjadi, ambil jenis pertama menurut urutan kJenis agar hasil
    // deterministik; catatan "disarankan ambil ulang" tetap tampil.
    final leaders = top.where((j) => (scores[j]! - bestScore).abs() < 1e-9).toList();
    return VoteResult(points, leaders.first, const [], false,
        scores: scores, tieBroken: true);
  }
  return VoteResult(points, null, top, false, scores: scores);
}

/// "buah-rawit" -> "Buah Rawit" (untuk label kotak deteksi).
String prettyClass(String cls) => _parts(cls).map(_cap).join(' ');
