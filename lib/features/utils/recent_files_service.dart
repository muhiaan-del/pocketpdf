import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class RecentFile {
  final String path;
  final String name;
  final DateTime openedAt;

  RecentFile({
    required this.path,
    required this.name,
    required this.openedAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'openedAt': openedAt.millisecondsSinceEpoch,
      };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        path: json['path'] as String,
        name: json['name'] as String,
        openedAt: DateTime.fromMillisecondsSinceEpoch(
          json['openedAt'] as int,
        ),
      );
}

class RecentFilesService {
  static const _key = 'recent_files_v1';
  static const _maxEntries = 10;

  /// Reads the list. Filters out files that no longer exist on disk.
  static Future<List<RecentFile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => RecentFile.fromJson(e as Map<String, dynamic>))
          .toList();
      // Filter out files that no longer exist.
      final alive = <RecentFile>[];
      for (final f in list) {
        if (await File(f.path).exists()) alive.add(f);
      }
      if (alive.length != list.length) {
        // Prune dead entries.
        await _save(alive);
      }
      return alive;
    } catch (_) {
      return [];
    }
  }

  /// Records a file as recently opened. Moves it to the top if already
  /// present, trims to [_maxEntries].
  static Future<void> record(String path, String name) async {
    final list = await load();
    list.removeWhere((f) => f.path == path);
    list.insert(
      0,
      RecentFile(path: path, name: name, openedAt: DateTime.now()),
    );
    if (list.length > _maxEntries) {
      list.removeRange(_maxEntries, list.length);
    }
    await _save(list);
  }

  /// Clears the whole list.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _save(List<RecentFile> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((f) => f.toJson()).toList()),
    );
  }
}