import 'dart:io';
import 'package:flutter/material.dart';
import 'history_store.dart';
import 'ui.dart';

class HistoryDetailPage extends StatefulWidget {
  const HistoryDetailPage({super.key, required this.item});

  final HistoryItem item;

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  bool _expanded = true;

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus riwayat?'),
        content: const Text('Hasil deteksi ini akan dihapus dari riwayat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await HistoryStore.delete(widget.item);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _stat(String title, String value) {
    return Expanded(
      child: GreyCard(
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final pct = (it.avgConf * 100).round();
    return Scaffold(
      appBar: const CapsiAppBar(showBack: true),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(child: Image.file(File(it.imagePath), fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SheetPanel(
              title: formatTanggal(it.time),
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hasil Deteksi : ${it.jenis}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _stat('Rata - Rata $kConfLabel', '$pct %'),
                      const SizedBox(width: 12),
                      _stat('Jumlah Objek', '${it.count} Objek'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pukul ${formatJam(it.time)}  |  Waktu proses ${it.ms} ms',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _confirmDelete,
                      style: outlinedRed(),
                      child: const Text('HAPUS'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
