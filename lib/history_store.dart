import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  final String id;
  final String time; // ISO 8601
  final String jenis;
  final double avgConf;
  final int count;
  final int ms;
  final String organs;
  final String imagePath;

  const HistoryItem({
    required this.id,
    required this.time,
    required this.jenis,
    required this.avgConf,
    required this.count,
    required this.ms,
    required this.organs,
    required this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'jenis': jenis,
        'avgConf': avgConf,
        'count': count,
        'ms': ms,
        'organs': organs,
        'imagePath': imagePath,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] as String,
        time: j['time'] as String,
        jenis: j['jenis'] as String,
        avgConf: (j['avgConf'] as num).toDouble(),
        count: j['count'] as int,
        ms: j['ms'] as int,
        organs: j['organs'] as String,
        imagePath: j['imagePath'] as String,
      );
}

class HistoryStore {
  static const _key = 'capsiscan_history';

  static Future<List<HistoryItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> add({
    required Uint8List imageBytes,
    required String jenis,
    required double avgConf,
    required int count,
    required int ms,
    required String organs,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final file = File('${dir.path}/scan_$id.png');
    await file.writeAsBytes(imageBytes);
    final item = HistoryItem(
      id: id,
      time: DateTime.now().toIso8601String(),
      jenis: jenis,
      avgConf: avgConf,
      count: count,
      ms: ms,
      organs: organs,
      imagePath: file.path,
    );
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(item.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> delete(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) => (jsonDecode(s) as Map<String, dynamic>)['id'] == item.id);
    await prefs.setStringList(_key, raw);
    final f = File(item.imagePath);
    if (await f.exists()) await f.delete();
  }
}
