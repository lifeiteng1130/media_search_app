import 'package:hive_flutter/hive_flutter.dart';
import '../../search/data/models/media_item.dart';

/// 历史记录仓库
class HistoryRepository {
  static const String _readHistoryBox = 'read_history';
  static const String _playHistoryBox = 'play_history';

  /// 获取阅读历史
  Future<List<HistoryRecord>> getReadHistory() async {
    final box = await Hive.openBox(_readHistoryBox);
    final List<HistoryRecord> records = [];

    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        records.add(HistoryRecord(
          detailUrl: key as String,
          title: map['title'] as String? ?? '',
          subtitle: map['chapterTitle'] as String? ?? '',
          coverUrl: map['coverUrl'] as String?,
          lastTime: DateTime.parse(map['lastReadTime'] as String),
          type: HistoryType.read,
        ));
      }
    }

    // 按时间排序
    records.sort((a, b) => b.lastTime.compareTo(a.lastTime));
    return records;
  }

  /// 获取播放历史
  Future<List<HistoryRecord>> getPlayHistory() async {
    final box = await Hive.openBox(_playHistoryBox);
    final List<HistoryRecord> records = [];

    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        records.add(HistoryRecord(
          detailUrl: key as String,
          title: map['title'] as String? ?? '',
          subtitle: map['source'] as String? ?? '',
          coverUrl: map['coverUrl'] as String?,
          lastTime: DateTime.parse(map['lastPlayTime'] as String),
          position: map['position'] as int?,
          type: HistoryType.play,
        ));
      }
    }

    // 按时间排序
    records.sort((a, b) => b.lastTime.compareTo(a.lastTime));
    return records;
  }

  /// 获取所有历史记录
  Future<List<HistoryRecord>> getAllHistory() async {
    final readHistory = await getReadHistory();
    final playHistory = await getPlayHistory();
    final allHistory = [...readHistory, ...playHistory];

    // 按时间排序
    allHistory.sort((a, b) => b.lastTime.compareTo(a.lastTime));
    return allHistory;
  }

  /// 删除阅读历史
  Future<void> deleteReadHistory(String detailUrl) async {
    final box = await Hive.openBox(_readHistoryBox);
    await box.delete(detailUrl);
  }

  /// 删除播放历史
  Future<void> deletePlayHistory(String detailUrl) async {
    final box = await Hive.openBox(_playHistoryBox);
    await box.delete(detailUrl);
  }

  /// 删除历史记录
  Future<void> deleteHistory(HistoryRecord record) async {
    if (record.type == HistoryType.read) {
      await deleteReadHistory(record.detailUrl);
    } else {
      await deletePlayHistory(record.detailUrl);
    }
  }

  /// 清空阅读历史
  Future<void> clearReadHistory() async {
    final box = await Hive.openBox(_readHistoryBox);
    await box.clear();
  }

  /// 清空播放历史
  Future<void> clearPlayHistory() async {
    final box = await Hive.openBox(_playHistoryBox);
    await box.clear();
  }

  /// 清空所有历史
  Future<void> clearAllHistory() async {
    await clearReadHistory();
    await clearPlayHistory();
  }
}

enum HistoryType { read, play }

class HistoryRecord {
  final String detailUrl;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final DateTime lastTime;
  final int? position;
  final HistoryType type;

  HistoryRecord({
    required this.detailUrl,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    required this.lastTime,
    this.position,
    required this.type,
  });
}
