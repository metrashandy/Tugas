import 'dart:io';
import 'package:flutter/material.dart';
import 'history_store.dart';

String formatTime(String iso) {
  final d = DateTime.parse(iso);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await HistoryStore.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _open(HistoryItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.jenis),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(item.imagePath)),
              ),
              const SizedBox(height: 12),
              Text('Waktu: ${formatTime(item.time)}'),
              Text('Jumlah objek: ${item.count}'),
              Text('Rata-rata confidence: ${(item.avgConf * 100).toStringAsFixed(1)}%'),
              Text('Waktu proses: ${item.ms} ms'),
              Text('Organ: ${item.organs}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await HistoryStore.delete(item);
              if (ctx.mounted) Navigator.pop(ctx);
              _reload();
            },
            child: const Text('Hapus'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('Belum ada riwayat pemindaian.'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final it = _items[i];
        return Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(File(it.imagePath), width: 56, height: 56, fit: BoxFit.cover),
            ),
            title: Text(it.jenis),
            subtitle: Text('${formatTime(it.time)} - ${it.count} objek'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(it),
          ),
        );
      },
    );
  }
}
