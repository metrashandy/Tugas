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
  const CapsiAppBar({super.key, this.showBack = false});

  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBack,
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
                Icon(
                  expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: Colors.black54,
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
          if (expanded) ...[
            const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }
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
