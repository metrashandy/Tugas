/// Logika voting multi-organ: setiap organ yang terdeteksi memberi satu suara
/// bagi jenis cabai pada nama kelasnya (mis. "daun-rawit" -> rawit).

const List<String> kJenis = ['rawit', 'besar', 'sala'];

/// true  = tiap NAMA KELAS unik memberi 1 suara (sama dengan kode Colab)
/// false = tiap KOTAK deteksi memberi 1 suara
const bool kVotePerUniqueClass = true;

class DetItem {
  final String className;
  final double confidence;
  const DetItem(this.className, this.confidence);
}

class VoteResult {
  final Map<String, int> points;
  final String? winner; // null jika seri atau tidak ada deteksi
  final List<String> tied;
  final bool noDetection;
  const VoteResult(this.points, this.winner, this.tied, this.noDetection);

  String get label {
    if (noDetection) return 'Tidak dapat ditentukan';
    if (winner == null) return 'Seri (${tied.map(_cap).join(' / ')})';
    return 'Cabai ${_cap(winner!)}';
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
  if (kVotePerUniqueClass) {
    for (final cls in items.map((e) => e.className).toSet()) {
      final j = jenisOf(cls);
      if (j != null) points[j] = points[j]! + 1;
    }
  } else {
    for (final it in items) {
      final j = jenisOf(it.className);
      if (j != null) points[j] = points[j]! + 1;
    }
  }
  final maxPoint = points.values.fold<int>(0, (a, b) => a > b ? a : b);
  if (maxPoint == 0) return VoteResult(points, null, const [], true);
  final top = points.entries.where((e) => e.value == maxPoint).map((e) => e.key).toList();
  if (top.length > 1) return VoteResult(points, null, top, false);
  return VoteResult(points, top.first, const [], false);
}
