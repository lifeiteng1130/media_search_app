import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/html_parser.dart';

class NovelRepository {
  final ApiClient _apiClient;
  static const String _cacheBoxName = 'novel_cache';

  NovelRepository(this._apiClient);

  Future<Box> _getCacheBox() async {
    if (!Hive.isBoxOpen(_cacheBoxName)) {
      return await Hive.openBox(_cacheBoxName);
    }
    return Hive.box(_cacheBoxName);
  }

  /// 获取小说章节列表
  Future<List<NovelChapter>> getChapters(String detailUrl, {bool useCache = true}) async {
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

      if (content.length > 100) {
        final cacheBox = await _getCacheBox();
        await cacheBox.put('content_$chapterUrl', content);
      }

      return content;
    } catch (e) {
      return '加载失败: $e';
    }
  }

  Future<void> clearCache() async {
    final cacheBox = await _getCacheBox();
    await cacheBox.clear();
  }

  List<NovelChapter> _parseChapters(String html, String baseUrl) {
    final chapters = <NovelChapter>[];
    final uri = Uri.parse(baseUrl);
    final base = '${uri.scheme}://${uri.host}';

    // 52bqg.org 格式: /book_xxx/xxxxx.html
    final pattern = RegExp(r'href="(/book_\d+/\d+\.html)"[^>]*>([^<]+)');
    final matches = pattern.allMatches(html);

    int index = 0;
    final seen = <String>{};
    for (final match in matches) {
      final path = match.group(1)!;
      final title = match.group(2)!.trim();

      if (title.isEmpty || title.length < 2) continue;
      if (seen.contains(path)) continue;
      seen.add(path);

      // 跳过目录页链接
      if (path.contains('index')) continue;

      final url = '$base$path';
      chapters.add(NovelChapter(
        title: title,
        url: url,
        index: index++,
      ));
    }

    // 如果上面的方法没找到，尝试通用选择器
    if (chapters.isEmpty) {
      final selectors = [
        '.chapter-list a',
        '.list-chapter a',
        '.chapterlist a',
        '#list a',
      ];

      for (final selector in selectors) {
        final elements = HtmlUtil.extractAll(html, selector);
        if (elements.isEmpty) continue;

        for (int i = 0; i < elements.length; i++) {
          final el = elements[i];
          final title = el.text.trim();
          var url = el.attributes['href'] ?? '';

          if (title.isEmpty || url.isEmpty) continue;

          if (!url.startsWith('http')) {
            url = '$base$url';
          }

          chapters.add(NovelChapter(
            title: title,
            url: url,
            index: i,
          ));
        }

        if (chapters.isNotEmpty) break;
      }
    }

    return chapters;
  }

  String _parseContent(String html) {
    // 52bqg.org 使用 base64 编码内容
    // 格式: document.writeln(qsbs.bb('base64string'));
    final base64Pattern = RegExp(r"qsbs\.bb\('([A-Za-z0-9+/=]+)'\)");
    final matches = base64Pattern.allMatches(html);

    if (matches.isNotEmpty) {
      final buffer = StringBuffer();
      for (final match in matches) {
        final encoded = match.group(1)!;
        try {
          final decoded = utf8.decode(base64Decode(encoded));
          // 提取 <p> 标签中的文本
          final text = decoded.replaceAll(RegExp(r'<[^>]+>'), '').trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        } catch (e) {
          // 解码失败，跳过
        }
      }

      if (buffer.isNotEmpty) {
        return _cleanContent(buffer.toString());
      }
    }

    // 尝试常见的内容选择器
    final selectors = [
      '#content',
      '.chapter-content',
      '.content',
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
        return _cleanContent(text);
      }
    }

    final body = HtmlUtil.extractText(html, 'body');
    return body != null ? _cleanContent(body) : '内容解析失败';
  }

  String _cleanContent(String text) {
    var cleaned = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r'请记住本书首发域名.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'笔趣阁.*最新章节.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'请关闭浏览器阅读模式.*'), '');
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
