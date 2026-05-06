import 'dart:convert';
import 'package:html/dom.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/data_sources.dart';
import '../../../core/utils/html_parser.dart';
import 'models/media_item.dart';
import 'models/media_type.dart';
import 'models/search_result.dart';

class SearchRepository {
  final ApiClient _apiClient;

  SearchRepository(this._apiClient);

  /// 搜索资源：聚合多个数据源
  Future<SearchResult> search(String query, {MediaType? type, int page = 1}) async {
    final futures = <Future<List<MediaItem>>>[];

    if (type == null || type == MediaType.movie || type == MediaType.tv) {
      for (final source in DataSources.videoSources) {
        futures.add(_searchVideoSource(source, query));
      }
    }

    if (type == null || type == MediaType.anime) {
      for (final source in DataSources.animeSources) {
        futures.add(_searchAnimeSource(source, query));
      }
    }

    if (type == null || type == MediaType.novel) {
      for (final source in DataSources.novelSources) {
        futures.add(_searchNovelSource(source, query));
      }
    }

    final results = await Future.wait(futures);
    final allItems = results.expand((r) => r).toList();

    // 去重
    final seen = <String>{};
    final unique = allItems.where((item) => seen.add(item.title)).toList();

    return SearchResult(items: unique, page: page);
  }

  // ========== 影视资源搜索 ==========

  Future<List<MediaItem>> _searchVideoSource(VideoSource source, String query) async {
    try {
      if (source.useApi) {
        return _searchApiSource(source.baseUrl, query, MediaType.movie, source.name);
      }
      final url = source.getSearchUrl(query);
      final html = await _apiClient.fetchHtml(url);
      return _parseGenericResults(html, source.name, source.baseUrl, MediaType.movie,
        resultSelector: source.resultSelector,
        titleSelector: source.titleSelector,
        linkSelector: source.linkSelector,
        coverSelector: source.coverSelector,
        descSelector: source.descSelector,
      );
    } catch (e) {
      return [];
    }
  }

  // ========== 动漫资源搜索 ==========

  Future<List<MediaItem>> _searchAnimeSource(AnimeSource source, String query) async {
    try {
      if (source.useApi) {
        return _searchApiSource(source.baseUrl, query, MediaType.anime, source.name);
      }
      final url = source.getSearchUrl(query);
      final html = await _apiClient.fetchHtml(url);
      return _parseGenericResults(html, source.name, source.baseUrl, MediaType.anime,
        resultSelector: source.resultSelector,
        titleSelector: source.titleSelector,
        linkSelector: source.linkSelector,
        coverSelector: source.coverSelector,
        descSelector: source.descSelector,
      );
    } catch (e) {
      return [];
    }
  }

  // ========== API 搜索（ffzy.tv 等 maccms 站点） ==========

  Future<List<MediaItem>> _searchApiSource(
    String baseUrl,
    String query,
    MediaType defaultType,
    String sourceName,
  ) async {
    try {
      final url = '$baseUrl/index.php/ajax/suggest?mid=1&wd=${Uri.encodeComponent(query)}&limit=20';
      final response = await _apiClient.get(url);
      final data = response.data;

      if (data is String) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        return _parseApiResults(json, baseUrl, defaultType, sourceName);
      } else if (data is Map<String, dynamic>) {
        return _parseApiResults(data, baseUrl, defaultType, sourceName);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  List<MediaItem> _parseApiResults(
    Map<String, dynamic> json,
    String baseUrl,
    MediaType defaultType,
    String sourceName,
  ) {
    final items = <MediaItem>[];
    final list = json['list'] as List?;

    if (list == null) return items;

    for (final item in list) {
      final id = item['id'] as int?;
      final name = item['name'] as String? ?? '';
      final pic = item['pic'] as String? ?? '';

      if (id == null || name.isEmpty) continue;

      // 根据名称判断类型
      var mediaType = defaultType;
      if (name.contains('动漫') || name.contains('番剧') || name.contains('动画')) {
        mediaType = MediaType.anime;
      }

      items.add(MediaItem(
        id: 'api_$id',
        title: name,
        coverUrl: pic.isNotEmpty ? pic : null,
        mediaType: mediaType,
        detailUrl: '$baseUrl/index.php/vod/detail/id/$id.html',
        source: sourceName,
      ));
    }

    return items;
  }

  // ========== 小说搜索 ==========

  Future<List<MediaItem>> _searchNovelSource(NovelSource source, String query) async {
    try {
      final url = source.getSearchUrl(query);
      String html;

      if (source.searchMethod == 'POST') {
        final body = source.getSearchBody(query);
        final response = await _apiClient.post(url, data: body);
        html = response.data as String;
      } else {
        html = await _apiClient.fetchHtml(url);
      }

      return _parseNovelResults(html, source.name, source.baseUrl,
        resultSelector: source.resultSelector,
        titleSelector: source.titleSelector,
        linkSelector: source.linkSelector,
        coverSelector: source.coverSelector,
        authorSelector: source.authorSelector,
      );
    } catch (e) {
      return [];
    }
  }

  // ========== 通用结果解析 ==========

  List<MediaItem> _parseGenericResults(
    String html,
    String source,
    String baseUrl,
    MediaType defaultType, {
    required String resultSelector,
    required String titleSelector,
    required String linkSelector,
    required String coverSelector,
    required String descSelector,
  }) {
    final items = <MediaItem>[];
    final selectors = [resultSelector, '.module-item', '.movie-item', '.search-result-item', '.card', 'li'];

    for (final selector in selectors) {
      if (selector.isEmpty) continue;
      final elements = HtmlUtil.extractAll(html, selector);
      if (elements.isEmpty) continue;

      for (final element in elements) {
        final item = _parseElement(element, source, baseUrl, defaultType,
          titleSelector: titleSelector,
          linkSelector: linkSelector,
          coverSelector: coverSelector,
          descSelector: descSelector,
        );
        if (item != null) items.add(item);
      }

      if (items.isNotEmpty) break;
    }

    return items;
  }

  MediaItem? _parseElement(
    Element element,
    String source,
    String baseUrl,
    MediaType defaultType, {
    required String titleSelector,
    required String linkSelector,
    required String coverSelector,
    required String descSelector,
  }) {
    final titleEl = element.querySelector(titleSelector) ??
        element.querySelector('h3, h2, .title, .name, a[title]');
    final title = titleEl?.text.trim() ?? titleEl?.attributes['title'] ?? '';
    if (title.isEmpty || title.length < 2) return null;

    final linkEl = element.querySelector(linkSelector) ?? element.querySelector('a[href]');
    var link = linkEl?.attributes['href'] ?? '';
    if (link.isNotEmpty && !link.startsWith('http')) {
      link = '$baseUrl$link';
    }

    final imgEl = element.querySelector(coverSelector) ?? element.querySelector('img');
    var cover = imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'] ?? '';
    if (cover.isNotEmpty && !cover.startsWith('http')) {
      cover = '$baseUrl$cover';
    }

    final descEl = element.querySelector(descSelector);
    final desc = descEl?.text.trim();

    return MediaItem(
      id: 'res_${link.hashCode}',
      title: title,
      coverUrl: cover.isNotEmpty ? cover : null,
      description: desc,
      mediaType: defaultType,
      detailUrl: link.isNotEmpty ? link : null,
      source: source,
    );
  }

  // ========== 小说结果解析 ==========

  List<MediaItem> _parseNovelResults(
    String html,
    String source,
    String baseUrl, {
    required String resultSelector,
    required String titleSelector,
    required String linkSelector,
    required String coverSelector,
    required String authorSelector,
  }) {
    final items = <MediaItem>[];
    final selectors = [resultSelector, '.book-item', '.search-item', 'dl', 'li'];

    for (final selector in selectors) {
      if (selector.isEmpty) continue;
      final elements = HtmlUtil.extractAll(html, selector);
      if (elements.isEmpty) continue;

      for (final element in elements) {
        final item = _parseNovelElement(element, source, baseUrl,
          titleSelector: titleSelector,
          linkSelector: linkSelector,
          coverSelector: coverSelector,
          authorSelector: authorSelector,
        );
        if (item != null) items.add(item);
      }

      if (items.isNotEmpty) break;
    }

    return items;
  }

  MediaItem? _parseNovelElement(
    Element element,
    String source,
    String baseUrl, {
    required String titleSelector,
    required String linkSelector,
    required String coverSelector,
    required String authorSelector,
  }) {
    final titleEl = element.querySelector(titleSelector) ??
        element.querySelector('h3, h2, .title, .bookname, a');
    final title = titleEl?.text.trim() ?? '';
    if (title.isEmpty || title.length < 2) return null;

    final linkEl = element.querySelector(linkSelector) ?? element.querySelector('a[href]');
    var link = linkEl?.attributes['href'] ?? '';
    if (link.isNotEmpty && !link.startsWith('http')) {
      link = '$baseUrl$link';
    }

    final imgEl = element.querySelector(coverSelector) ?? element.querySelector('img');
    var cover = imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'] ?? '';
    if (cover.isNotEmpty && !cover.startsWith('http')) {
      cover = '$baseUrl$cover';
    }

    final authorEl = element.querySelector(authorSelector);
    final author = authorEl?.text.trim();

    return MediaItem(
      id: 'novel_${link.hashCode}',
      title: title,
      coverUrl: cover.isNotEmpty ? cover : null,
      description: author != null ? '作者: $author' : null,
      mediaType: MediaType.novel,
      detailUrl: link.isNotEmpty ? link : null,
      source: source,
    );
  }
}
