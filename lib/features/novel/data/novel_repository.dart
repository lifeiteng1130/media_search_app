import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/html_parser.dart';

class NovelRepository {
  final ApiClient _apiClient;
  static const String _cacheBoxName = 'novel_cache';

  NovelRepository(this._apiClient);

  /// 获取缓存 Box
  Future<Box> _getCacheBox() async {
    if (!Hive.isBoxOpen(_cacheBoxName)) {
      return await Hive.openBox(_cacheBoxName);
    }
    return Hive.box(_cacheBoxName);
  }

  /// 获取小说章节列表
  Future<List<NovelChapter>> getChapters(String detailUrl, {bool useCache = true}) async {
    // 尝试从缓存获取
    if (useCache) {
      final cacheBox = await _getCacheBox();
      final cached = cacheBox.get('chapters_$detailUrl');
      if (cached != null) {
        final List<dynamic> data = cached;
        return data.map((item) => NovelChapter.fromJson(Map<String, dynamic>.from(item))).toList();
      }
    }

    try {
      final html = await _apiClient.fetchHtml(detailUrl);
      final chapters = _parseChapters(html, detailUrl);

      // 缓存结果
      if (chapters.isNotEmpty) {
        final cacheBox = await _getCacheBox();
        await cacheBox.put('chapters_$detailUrl', chapters.map((c) => c.toJson()).toList());
      }

      return chapters;
    } catch (e) {
      return [];
    }
  }

  /// 获取章节内容
  Future<String> getChapterContent(String chapterUrl, {bool useCache = true}) async {
    // 尝试从缓存获取
    if (useCache) {
      final cacheBox = await _getCacheBox();
      final cached = cacheBox.get('content_$chapterUrl');
      if (cached != null) {
        return cached as String;
      }
    }

    try {
      final html = await _apiClient.fetchHtml(chapterUrl);
      final content = _parseContent(html);

      // 缓存内容
      if (content.length > 100) {
        final cacheBox = await _getCacheBox();
        await cacheBox.put('content_$chapterUrl', content);
      }

      return content;
    } catch (e) {
      return '加载失败: $e';
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    final cacheBox = await _getCacheBox();
    await cacheBox.clear();
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    final cacheBox = await _getCacheBox();
    return cacheBox.length;
  }

  List<NovelChapter> _parseChapters(String html, String baseUrl) {
    final chapters = <NovelChapter>[];

    // 尝试多种选择器
    final selectors = [
      '.chapter-list a',
      '.list-chapter a',
      '.chapterlist a',
      '.volume-wrap a',
      '#list a',
      '.book-list a',
    ];

    for (final selector in selectors) {
      final elements = HtmlUtil.extractAll(html, selector);
      if (elements.isEmpty) continue;

      for (int i = 0; i < elements.length; i++) {
        final el = elements[i];
        final title = el.text.trim();
        var url = el.attributes['href'] ?? '';

        if (title.isEmpty || url.isEmpty) continue;

        // 处理相对 URL
        if (!url.startsWith('http')) {
          final uri = Uri.parse(baseUrl);
          url = '${uri.scheme}://${uri.host}$url';
        }

        chapters.add(NovelChapter(
          title: title,
          url: url,
          index: i,
        ));
      }

      if (chapters.isNotEmpty) break;
    }

    return chapters;
  }

  String _parseContent(String html) {
    // 尝试多种常见的内容选择器
    final selectors = [
      '.chapter-content',
      '.content',
      '#content',
      '.read-content',
      '.novel-content',
      '.txtnav',
      '#chaptercontent',
      '.chapter_body',
      'article',
    ];

    for (final selector in selectors) {
      final text = HtmlUtil.extractText(html, selector);
      if (text != null && text.length > 100) {
        // 清理文本
        return _cleanContent(text);
      }
    }

    // 如果都没找到，尝试提取 body 中的文本
    final body = HtmlUtil.extractText(html, 'body');
    return body != null ? _cleanContent(body) : '内容解析失败';
  }

  String _cleanContent(String text) {
    // 移除多余空白行
    var cleaned = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // 移除广告文本
    cleaned = cleaned.replaceAll(RegExp(r'请记住本书首发域名.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'笔趣阁.*最新章节.*'), '');
    return cleaned.trim();
  }
}

class NovelChapter {
  final String title;
  final String url;
  final int index;

  const NovelChapter({required this.title, required this.url, required this.index});

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'index': index,
    };
  }

  factory NovelChapter.fromJson(Map<String, dynamic> json) {
    return NovelChapter(
      title: json['title'] as String,
      url: json['url'] as String,
      index: json['index'] as int,
    );
  }
}
