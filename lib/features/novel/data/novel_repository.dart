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

    // 优先从章节列表容器内提取（避免匹配到导航、推荐等区域的链接）
    final containerSelectors = ['#list', '.listmain', '.chapter-list', '.volume-wrap', '.book-list'];
    for (final selector in containerSelectors) {
      final containers = HtmlUtil.extractAll(html, selector);
      if (containers.isEmpty) continue;

      final container = containers.first;
      final links = container.querySelectorAll('a');
      if (links.isEmpty) continue;

      final seen = <String>{};
      for (final link in links) {
        final title = link.text.trim();
        var url = link.attributes['href'] ?? '';
        if (title.isEmpty || title.length < 2 || url.isEmpty) continue;

        if (!url.startsWith('http')) {
          url = '$base$url';
        }

        if (seen.contains(url)) continue;
        seen.add(url);

        chapters.add(NovelChapter(title: title, url: url, index: 0));
      }

      if (chapters.isNotEmpty) break;
    }

    // Fallback：正则匹配章节链接
    if (chapters.isEmpty) {
      final patterns = [
        RegExp(r'href="(/book_\d+/\d+\.html)"[^>]*>([^<]+)'),
        RegExp(r'href="(/\d+/\d+\.html)"[^>]*>([^<]+)'),
      ];

      final seen = <String>{};
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(html)) {
          final path = match.group(1)!;
          final title = match.group(2)!.trim();

          if (title.isEmpty || title.length < 2) continue;
          if (seen.contains(path)) continue;
          seen.add(path);

          if (path.contains('index')) continue;

          final url = '$base$path';
          chapters.add(NovelChapter(title: title, url: url, index: 0));
        }
        if (chapters.isNotEmpty) break;
      }
    }

    // 按 URL 中的数字排序（/book_xxx/123.html 中的 123）
    if (chapters.isNotEmpty) {
      final numPattern = RegExp(r'/(\d+)\.html$');
      chapters.sort((a, b) {
        final aMatch = numPattern.firstMatch(a.url);
        final bMatch = numPattern.firstMatch(b.url);
        final aNum = aMatch != null ? int.tryParse(aMatch.group(1)!) ?? 0 : 0;
        final bNum = bMatch != null ? int.tryParse(bMatch.group(1)!) ?? 0 : 0;
        return aNum.compareTo(bNum);
      });

      // 重新分配 index
      for (int i = 0; i < chapters.length; i++) {
        chapters[i] = NovelChapter(
          title: chapters[i].title,
          url: chapters[i].url,
          index: i,
        );
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
