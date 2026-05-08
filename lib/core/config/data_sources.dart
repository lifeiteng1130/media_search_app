/// 数据源配置
class DataSources {
  // ========== 影视资源站点（MacCMS API 格式） ==========
  static const videoSources = [
    VideoSource(
      name: '非凡资源',
      baseUrl: 'https://www.ffzy.tv',
      searchPath: '/index.php/ajax/suggest?mid=1&wd={query}&limit=20',
      resultSelector: '',
      titleSelector: '',
      linkSelector: '',
      coverSelector: '',
      descSelector: '',
      useApi: true,
    ),
    VideoSource(
      name: '暴风资源',
      baseUrl: 'https://www.bfzy.tv',
      searchPath: '/index.php/ajax/suggest?mid=1&wd={query}&limit=20',
      resultSelector: '',
      titleSelector: '',
      linkSelector: '',
      coverSelector: '',
      descSelector: '',
      useApi: true,
    ),
    VideoSource(
      name: '华为资源',
      baseUrl: 'https://www.hwzy.net',
      searchPath: '/index.php/ajax/suggest?mid=1&wd={query}&limit=20',
      resultSelector: '',
      titleSelector: '',
      linkSelector: '',
      coverSelector: '',
      descSelector: '',
      useApi: true,
    ),
    VideoSource(
      name: '八戒资源',
      baseUrl: 'https://www.bajiezy.com',
      searchPath: '/index.php/ajax/suggest?mid=1&wd={query}&limit=20',
      resultSelector: '',
      titleSelector: '',
      linkSelector: '',
      coverSelector: '',
      descSelector: '',
      useApi: true,
    ),
    VideoSource(
      name: '快看资源',
      baseUrl: 'https://www.kuaikanzy.cc',
      searchPath: '/index.php/ajax/suggest?mid=1&wd={query}&limit=20',
      resultSelector: '',
      titleSelector: '',
      linkSelector: '',
      coverSelector: '',
      descSelector: '',
      useApi: true,
    ),
  ];

  // ========== 小说资源站点 ==========
  static const novelSources = [
    NovelSource(
      name: '笔趣阁',
      baseUrl: 'https://www.52bqg.org',
      searchPath: '/search.html',
      searchMethod: 'POST',
      searchParam: 's',
      resultSelector: '.txt-list li',
      titleSelector: '.s2 a',
      linkSelector: '.s2 a',
      coverSelector: 'img',
      authorSelector: '.s3 a',
      chapterSelector: '',
      contentSelector: '',
    ),
    NovelSource(
      name: '新笔趣阁',
      baseUrl: 'https://www.xbiquge.so',
      searchPath: '/search.html',
      searchMethod: 'POST',
      searchParam: 's',
      resultSelector: '.txt-list li',
      titleSelector: '.s2 a',
      linkSelector: '.s2 a',
      coverSelector: 'img',
      authorSelector: '.s4',
      chapterSelector: '',
      contentSelector: '',
    ),
  ];

  // ========== 动漫资源站点（复用 MacCMS API） ==========
  static const animeSources = [
    AnimeSource(
      name: '非凡动漫',
      baseUrl: 'https://www.ffzy.tv',
      searchPath: '/index.php/ajax/suggest?mid=1&wd={query}&limit=20',
      resultSelector: '',
      titleSelector: '',
      linkSelector: '',
      coverSelector: '',
      descSelector: '',
      useApi: true,
    ),
    AnimeSource(
      name: '暴风动漫',
      baseUrl: 'https://www.bfzy.tv',
      searchPath: '/index.php/ajax/suggest?mid=1&wd={query}&limit=20',
      resultSelector: '',
      titleSelector: '',
      linkSelector: '',
      coverSelector: '',
      descSelector: '',
      useApi: true,
    ),
    AnimeSource(
      name: '华为动漫',
      baseUrl: 'https://www.hwzy.net',
      searchPath: '/index.php/ajax/suggest?mid=1&wd={query}&limit=20',
      resultSelector: '',
      titleSelector: '',
      linkSelector: '',
      coverSelector: '',
      descSelector: '',
      useApi: true,
    ),
  ];
}

class VideoSource {
  final String name;
  final String baseUrl;
  final String searchPath;
  final String resultSelector;
  final String titleSelector;
  final String linkSelector;
  final String coverSelector;
  final String descSelector;
  final bool useApi;

  const VideoSource({
    required this.name,
    required this.baseUrl,
    required this.searchPath,
    required this.resultSelector,
    required this.titleSelector,
    required this.linkSelector,
    required this.coverSelector,
    required this.descSelector,
    this.useApi = false,
  });

  String getSearchUrl(String query) {
    return '$baseUrl${searchPath.replaceAll('{query}', Uri.encodeComponent(query))}';
  }
}

class NovelSource {
  final String name;
  final String baseUrl;
  final String searchPath;
  final String searchMethod;
  final String searchParam;
  final String resultSelector;
  final String titleSelector;
  final String linkSelector;
  final String coverSelector;
  final String authorSelector;
  final String chapterSelector;
  final String contentSelector;

  const NovelSource({
    required this.name,
    required this.baseUrl,
    required this.searchPath,
    this.searchMethod = 'GET',
    this.searchParam = 'q',
    required this.resultSelector,
    required this.titleSelector,
    required this.linkSelector,
    required this.coverSelector,
    required this.authorSelector,
    required this.chapterSelector,
    required this.contentSelector,
  });

  String getSearchUrl(String query) {
    if (searchMethod == 'POST') {
      return '$baseUrl$searchPath';
    }
    return '$baseUrl${searchPath.replaceAll('{query}', Uri.encodeComponent(query))}';
  }

  Map<String, String> getSearchBody(String query) {
    if (searchMethod == 'POST') {
      return {searchParam: query};
    }
    return {};
  }
}

class AnimeSource {
  final String name;
  final String baseUrl;
  final String searchPath;
  final String resultSelector;
  final String titleSelector;
  final String linkSelector;
  final String coverSelector;
  final String descSelector;
  final bool useApi;

  const AnimeSource({
    required this.name,
    required this.baseUrl,
    required this.searchPath,
    required this.resultSelector,
    required this.titleSelector,
    required this.linkSelector,
    required this.coverSelector,
    required this.descSelector,
    this.useApi = false,
  });

  String getSearchUrl(String query) {
    return '$baseUrl${searchPath.replaceAll('{query}', Uri.encodeComponent(query))}';
  }
}
