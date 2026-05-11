import 'package:hive_flutter/hive_flutter.dart';
import '../core/network/api_client.dart';
import '../core/utils/rule_engine.dart';
import '../models/book_source.dart';
import '../models/book_chapter.dart';
import '../models/book_search_result.dart';
import 'book_source_repository.dart';

class BookRepository {
  final ApiClient _apiClient;
  final BookSourceRepository _sourceRepo;
  static const String _cacheBoxName = 'novel_cache';

  BookRepository(this._apiClient, this._sourceRepo);

  Future<Box> _getCacheBox() async {
    if (!Hive.isBoxOpen(_cacheBoxName)) {
      return await Hive.openBox(_cacheBoxName);
    }
    return Hive.box(_cacheBoxName);
  }

  /// 搜索小说
  Future<List<BookSearchResult>> search(String query) async {
    final sources = await _sourceRepo.getEnabled();
    if (sources.isEmpty) return [];

    final futures = sources.map((s) => _searchSource(s, query));
    final results = await Future.wait(futures, eagerError: false);
    final allItems = results.expand((r) => r).toList();

    final seen = <String>{};
    return allItems.where((item) => seen.add(item.title)).toList();
  }

  Future<List<BookSearchResult>> _searchSource(BookSource source, String query) async {
    try {
      final searchUrl = source.getSearchUrl(query);
      String html;

      if (source.isPostSearch) {
        final body = source.getSearchBody(query);
        final response = await _apiClient.post(searchUrl, data: body);
        html = response.data as String;
      } else {
        html = await _apiClient.fetchHtml(searchUrl);
      }

      return _parseSearchResults(html, source);
    } catch (e) {
      return [];
    }
  }

  List<BookSearchResult> _parseSearchResults(String html, BookSource source) {
    final rule = source.ruleSearch;
    if (rule == null) return [];

    final items = <BookSearchResult>[];
    final elements = RuleEngine.extractAll(html, rule.bookList);

    for (final element in elements) {
      final name = RuleEngine.extractFromElement(element, rule.name);
      if (name == null || name.isEmpty || name.length < 2) continue;

      var bookUrl = RuleEngine.extractFromElement(element, rule.bookUrl) ?? '';
      if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
        bookUrl = RuleEngine.resolveUrl(source.bookSourceUrl, bookUrl);
      }
      if (bookUrl.isEmpty) continue;

      var coverUrl = rule.coverUrl.isNotEmpty
          ? RuleEngine.extractFromElement(element, rule.coverUrl)
          : null;
      if (coverUrl != null && coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = RuleEngine.resolveUrl(source.bookSourceUrl, coverUrl);
      }

      final author = rule.author.isNotEmpty
          ? RuleEngine.extractFromElement(element, rule.author)
          : null;
      final intro = rule.intro.isNotEmpty
          ? RuleEngine.extractFromElement(element, rule.intro)
          : null;

      items.add(BookSearchResult(
        title: name,
        author: author,
        coverUrl: coverUrl?.isNotEmpty == true ? coverUrl : null,
        intro: intro,
        detailUrl: bookUrl,
        source: source.bookSourceName,
        bookSourceUrl: source.bookSourceUrl,
      ));
    }

    return items;
  }

  /// 获取章节列表
  Future<List<BookChapter>> getChapters(String detailUrl, BookSource source) async {
    final cacheKey = 'chapters_${source.bookSourceUrl}_$detailUrl';
    final cacheBox = await _getCacheBox();
    final cached = cacheBox.get(cacheKey);
    if (cached != null) {
      final List<dynamic> data = cached;
      return data.map((item) => BookChapter.fromJson(Map<String, dynamic>.from(item))).toList();
    }

    try {
      var html = await _apiClient.fetchHtml(detailUrl).timeout(const Duration(seconds: 15));
      var tocUrl = detailUrl;

      if (source.ruleBookInfo?.tocUrl != null && source.ruleBookInfo!.tocUrl.isNotEmpty) {
        final extractedTocUrl = RuleEngine.extractText(html, source.ruleBookInfo!.tocUrl, baseUrl: detailUrl);
        if (extractedTocUrl != null && extractedTocUrl.isNotEmpty) {
          tocUrl = RuleEngine.resolveUrl(detailUrl, extractedTocUrl);
          if (tocUrl != detailUrl) {
            html = await _apiClient.fetchHtml(tocUrl).timeout(const Duration(seconds: 15));
          }
        }
      }

      final chapters = _parseChapters(html, source, tocUrl);

      if (chapters.isNotEmpty) {
        await cacheBox.put(cacheKey, chapters.map((c) => c.toJson()).toList());
      }

      return chapters;
    } catch (e) {
      return [];
    }
  }

  List<BookChapter> _parseChapters(String html, BookSource source, String baseUrl) {
    final rule = source.ruleToc;
    if (rule == null) return [];

    final chapters = <BookChapter>[];
    final elements = RuleEngine.extractAll(html, rule.chapterList);

    for (int i = 0; i < elements.length; i++) {
      final element = elements[i];

      String chapterName;
      if (rule.chapterName == 'text' || rule.chapterName.isEmpty) {
        chapterName = element.text.trim();
      } else {
        chapterName = RuleEngine.extractFromElement(element, rule.chapterName) ?? element.text.trim();
      }

      String chapterUrl;
      if (rule.chapterUrl == 'href' || rule.chapterUrl.isEmpty) {
        chapterUrl = element.attributes['href'] ?? '';
      } else {
        chapterUrl = RuleEngine.extractFromElement(element, rule.chapterUrl) ?? '';
      }

      if (chapterName.isEmpty || chapterUrl.isEmpty) continue;

      if (!chapterUrl.startsWith('http')) {
        chapterUrl = RuleEngine.resolveUrl(baseUrl, chapterUrl);
      }

      chapters.add(BookChapter(title: chapterName, url: chapterUrl, index: i));
    }

    return chapters;
  }

  /// 获取章节内容
  Future<String> getChapterContent(String chapterUrl, BookSource source) async {
    final cacheKey = 'content_${source.bookSourceUrl}_$chapterUrl';
    final cacheBox = await _getCacheBox();
    final cached = cacheBox.get(cacheKey);
    if (cached != null) return cached as String;

    try {
      final html = await _apiClient.fetchHtml(chapterUrl).timeout(const Duration(seconds: 15));
      var content = _parseContent(html, source);

      if (source.ruleContent?.nextContentUrl != null && source.ruleContent!.nextContentUrl.isNotEmpty) {
        var nextUrl = RuleEngine.extractText(html, source.ruleContent!.nextContentUrl, baseUrl: chapterUrl);
        int pageCount = 0;
        while (nextUrl != null && nextUrl.isNotEmpty && pageCount < 10) {
          if (!nextUrl.startsWith('http')) {
            nextUrl = RuleEngine.resolveUrl(chapterUrl, nextUrl);
          }
          final nextHtml = await _apiClient.fetchHtml(nextUrl).timeout(const Duration(seconds: 15));
          final nextContent = _extractContent(nextHtml, source);
          if (nextContent.isNotEmpty) {
            content += '\n\n$nextContent';
          }
          nextUrl = RuleEngine.extractText(nextHtml, source.ruleContent!.nextContentUrl, baseUrl: nextUrl);
          pageCount++;
        }
      }

      if (content.length > 100) {
        await cacheBox.put(cacheKey, content);
      }

      return content;
    } catch (e) {
      return '章节内容加载失败，请尝试换源';
    }
  }

  String _parseContent(String html, BookSource source) {
    var content = _extractContent(html, source);
    content = _cleanContent(content);
    return content;
  }

  String _extractContent(String html, BookSource source) {
    final rule = source.ruleContent;
    if (rule == null) return '';

    final text = RuleEngine.extractText(html, rule.content, baseUrl: source.bookSourceUrl);
    if (text == null || text.isEmpty) return '';

    if (rule.replaceRegex.isNotEmpty) {
      return RuleEngine.applyReplace(text, rule.replaceRegex);
    }

    return text;
  }

  String _cleanContent(String text) {
    var cleaned = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r'请记住本书首发域名.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'笔趣阁.*最新章节.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'请关闭浏览器阅读模式.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), '');
    return cleaned.trim();
  }

  Future<void> clearCache() async {
    final cacheBox = await _getCacheBox();
    await cacheBox.clear();
  }
}
