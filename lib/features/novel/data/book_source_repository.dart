import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'book_source.dart';
import 'default_book_sources.dart';
import '../../../core/network/api_client.dart';

/// 书源仓库 - 管理小说书源的 CRUD 和导入导出
class BookSourceRepository {
  static const String _boxName = 'book_sources';
  static const String _allKey = 'all_sources';
  static const String _initializedKey = 'defaults_loaded';

  final ApiClient _apiClient;

  BookSourceRepository(this._apiClient);

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// 获取所有书源
  Future<List<BookSource>> getAll() async {
    final box = await _getBox();
    final data = box.get(_allKey);
    if (data == null) return [];
    final List<dynamic> list = data;
    return list
        .map((e) => BookSource.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 获取启用的书源
  Future<List<BookSource>> getEnabled() async {
    final all = await getAll();
    return all.where((s) => s.enabled && s.ruleSearch != null).toList();
  }

  /// 保存所有书源
  Future<void> _saveAll(List<BookSource> sources) async {
    final box = await _getBox();
    await box.put(_allKey, sources.map((e) => e.toJson()).toList());
  }

  /// 添加或更新书源
  Future<void> save(BookSource source) async {
    final sources = await getAll();
    final index = sources.indexWhere((s) => s.bookSourceUrl == source.bookSourceUrl);
    if (index >= 0) {
      sources[index] = source;
    } else {
      sources.add(source);
    }
    await _saveAll(sources);
  }

  /// 删除书源
  Future<void> delete(String url) async {
    final sources = await getAll();
    sources.removeWhere((s) => s.bookSourceUrl == url);
    await _saveAll(sources);
  }

  /// 切换启用状态
  Future<void> toggleEnabled(String url) async {
    final sources = await getAll();
    final index = sources.indexWhere((s) => s.bookSourceUrl == url);
    if (index >= 0) {
      sources[index] = sources[index].copyWith(enabled: !sources[index].enabled);
      await _saveAll(sources);
    }
  }

  /// 全部启用/禁用
  Future<void> setAllEnabled(bool enabled) async {
    final sources = await getAll();
    final updated = sources.map((s) => s.copyWith(enabled: enabled)).toList();
    await _saveAll(updated);
  }

  /// 从 JSON 字符串导入书源（兼容 Legado 格式）
  Future<int> importFromJson(String jsonStr) async {
    final newSources = parseBookSourcesJson(jsonStr);
    if (newSources.isEmpty) return 0;

    final existing = await getAll();
    final existingUrls = existing.map((s) => s.bookSourceUrl).toSet();

    var addedCount = 0;
    for (final source in newSources) {
      if (!existingUrls.contains(source.bookSourceUrl)) {
        existing.add(source);
        addedCount++;
      }
    }

    if (addedCount > 0) {
      await _saveAll(existing);
    }
    return addedCount;
  }

  /// 从 URL 导入书源
  Future<int> importFromUrl(String url) async {
    try {
      final response = await _apiClient.get(url);
      final jsonStr = response.data as String;
      return importFromJson(jsonStr);
    } catch (e) {
      return 0;
    }
  }

  /// 导出书源为 JSON
  String exportToJson(List<BookSource> sources) {
    final list = sources.map((e) => e.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// 加载默认书源（首次启动时调用）
  Future<void> loadDefaults() async {
    final box = await _getBox();
    final initialized = box.get(_initializedKey, defaultValue: false);
    if (initialized) return;

    final defaults = await loadDefaultBookSources();
    if (defaults.isNotEmpty) {
      await _saveAll(defaults);
      await box.put(_initializedKey, true);
    }
  }

  /// 强制重新加载默认书源
  Future<void> reloadDefaults() async {
    final defaults = await loadDefaultBookSources();
    if (defaults.isEmpty) return;

    final existing = await getAll();
    final existingUrls = existing.map((s) => s.bookSourceUrl).toSet();

    for (final source in defaults) {
      if (!existingUrls.contains(source.bookSourceUrl)) {
        existing.add(source);
      }
    }
    await _saveAll(existing);
  }

  /// 根据 URL 查找匹配的书源
  Future<BookSource?> findByUrl(String url) async {
    final sources = await getAll();
    for (final source in sources) {
      if (url.startsWith(source.bookSourceUrl)) {
        return source;
      }
    }
    return null;
  }
}
