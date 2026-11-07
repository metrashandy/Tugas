import 'dart:typed_data';
import 'package:flutter/material.dart';

const Color kRed = Color(0xFFFE1C1C);
const Color kRedDark = Color(0xFFB80F0F);
const Color kBoxGreen = Color(0xFF6CFF00);
const Color kGreyCard = Color(0xFFE0E0E0);

/// Nama font judul (serif bawaan Android).
const String kSerif = 'serif';

/// Istilah skor keyakinan model di antarmuka. Desain laporan memakai "Akurasi";
/// secara teknis skor ini adalah confidence. Ubah di sini bila ingin diganti.
const String kConfLabel = 'Akurasi';

const List<String> _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String formatTanggal(String iso) {
  final d = DateTime.parse(iso);
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}

String formatJam(String iso) {
  final d = DateTime.parse(iso);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}.${two(d.minute)}';
}

class CapsiAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CapsiAppBar({super.key, this.showBack = false, this.onBack});

  /// Tombol kembali otomatis (untuk halaman yang di-push lewat Navigator).
  final bool showBack;

  /// Tombol kembali manual (untuk berpindah tampilan di halaman utama).
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBack && onBack == null,
      leading: onBack == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Kembali',
              onPressed: onBack,
            ),
      foregroundColor: Colors.white,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Text(
        'CapsiScan',
        style: TextStyle(
          fontFamily: kSerif,
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kRedDark, kRed],
          ),
        ),
      ),
    );
  }
}

class CapsiBottomBar extends StatelessWidget {
  const CapsiBottomBar({
    super.key,
    required this.onUpload,
    required this.onCamera,
    required this.onHistory,
    this.historyActive = false,
  });

  final VoidCallback onUpload;
  final VoidCallback onCamera;
  final VoidCallback onHistory;
  final bool historyActive;

  Widget _side(IconData icon, String label, VoidCallback onTap, bool active) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kRed,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _side(Icons.folder_open, 'Upload Gambar', onUpload, false),
              Expanded(
                child: InkWell(
                  onTap: onCamera,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: kRed, size: 26),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'AMBIL GAMBAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _side(Icons.history, 'Riwayat', onHistory, historyActive),
            ],
          ),
        ),
      ),
    );
  }
}

class GreyCard extends StatelessWidget {
  const GreyCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: kGreyCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

/// Panel putih di bagian bawah layar (bottom sheet) sesuai desain.
/// Buka/tutup isi panel dianimasikan dengan AnimatedSize (ringan, satu
/// animasi layout, tanpa bayangan atau blur tambahan).
class SheetPanel extends StatelessWidget {
  const SheetPanel({
    super.key,
    required this.title,
    required this.child,
    this.expanded = true,
    this.onToggle,
  });

  final String title;
  final Widget child;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(blurRadius: 12, color: Color(0x33000000))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: Column(
              children: [
                AnimatedRotation(
                  turns: expanded ? 0 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: kSerif,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Meluncur naik + tetap ringan: satu Tween, tanpa Opacity (menghindari
/// layer tambahan). Dimainkan sekali saat widget pertama kali muncul.
class SlideUpIn extends StatelessWidget {
  const SlideUpIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) =>
          FractionalTranslation(translation: Offset(0, v), child: child),
      child: child,
    );
  }
}

/// Tampilan saat citra diproses: foto yang dipilih diredupkan, garis pemindai
/// hijau bergerak naik-turun, dan label tahap proses di bawah.
///
/// Ringan karena: satu AnimationController; hanya CustomPainter (di dalam
/// RepaintBoundary) yang digambar ulang tiap frame, widget lain tidak
/// di-rebuild; tanpa blur/MaskFilter; gambar didekode dalam ukuran kecil
/// (cacheWidth).
class ScanningView extends StatefulWidget {
  const ScanningView({super.key, required this.image, required this.stage});

  final Uint8List image;
  final ValueListenable<String> stage;

  @override
  State<ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<ScanningView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Image.memory(
          widget.image,
          fit: BoxFit.contain,
          cacheWidth: 1080,
          gaplessPlayback: true,
        ),
        const ColoredBox(color: Color(0x59000000)),
        RepaintBoundary(
          child: CustomPaint(
            painter: _ScanLinePainter(_ctrl),
            size: Size.infinite,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(child: _StageChip(stage: widget.stage)),
        ),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});

  final ValueListenable<String> stage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: stage,
      builder: (context, s, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            '$s...',
            key: ValueKey<String>(s),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter(this.t) : super(repaint: t);

  final AnimationController t;

  static const double _band = 90;
  static final Paint _linePaint = Paint()..color = const Color(0xFF6CFF00);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double p = Curves.easeInOutSine.transform(t.value);
    final double y = p * size.height;
    final bool down = t.status != AnimationStatus.reverse;

    // Jejak redup di belakang garis (di atas garis saat turun, di bawah saat naik).
    final double far = down ? y - _band : y + _band;
    final Rect trail = Rect.fromPoints(Offset(0, y), Offset(size.width, far));
    final gradient = LinearGradient(
      begin: down ? Alignment.topCenter : Alignment.bottomCenter,
      end: down ? Alignment.bottomCenter : Alignment.topCenter,
      colors: const [Color(0x006CFF00), Color(0x596CFF00)],
    );
    canvas.drawRect(trail, Paint()..shader = gradient.createShader(trail));

    canvas.drawRect(Rect.fromLTWH(0, y - 1.5, size.width, 3), _linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => old.t != t;
}

ButtonStyle filledRed() => FilledButton.styleFrom(
      backgroundColor: kRed,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );

ButtonStyle outlinedRed() => OutlinedButton.styleFrom(
      foregroundColor: kRed,
      side: const BorderSide(color: kRed),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
