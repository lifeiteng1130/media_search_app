/// 数据源配置
/// 在这里添加或修改资源站点
/// 每个站点需要配置: 名称、搜索URL模板、结果解析选择器
class DataSources {
  // ========== 影视资源站点 ==========

  static const videoSources = [
    VideoSource(
      name: '低端影视',
      baseUrl: 'https://ddrk.me',
      searchPath: '/search?keyword={query}',
      resultSelector: '.module-item',
      titleSelector: '.title',
      linkSelector: 'a[href]',
      coverSelector: 'img',
      descSelector: '.description',
    ),
    VideoSource(
      name: '奈飞影视',
      baseUrl: 'https://www.nfmovie.com',
      searchPath: '/search?keyword={query}',
      resultSelector: '.movie-item',
      titleSelector: '.name',
      linkSelector: 'a[href]',
      coverSelector: 'img',
      descSelector: '.intro',
    ),
  ];

  // ========== 小说资源站点 ==========
  static const novelSources = [
    NovelSource(
      name: '笔趣阁',
      baseUrl: 'https://www.xbiquge.so',
      searchPath: '/search.html',
      searchMethod: 'POST',
      searchParam: 's',
      resultSelector: 'dl',
      titleSelector: 'h3 a',
      linkSelector: 'a[href]',
      coverSelector: 'img',
      authorSelector: '.info',
      chapterSelector: '.list-chapter a',
      contentSelector: '#content',
    ),
    NovelSource(
      name: '新笔趣阁',
      baseUrl: 'https://www.bq730.cc',
      searchPath: '/search.php?q={query}',
      resultSelector: '.book-item',
      titleSelector: '.bookname a',
      linkSelector: 'a[href]',
      coverSelector: 'img',
      authorSelector: '.author',
      chapterSelector: '.chapterlist a',
      contentSelector: '.txtnav',
    ),
  ];

  // ========== 动漫资源站点 ==========
  static const animeSources = [
    AnimeSource(
      name: '樱花动漫',
      baseUrl: 'https://www.yhdm.so',
      searchPath: '/search?keyword={query}',
      resultSelector: '.video-item',
      titleSelector: '.title',
      linkSelector: 'a[href]',
      coverSelector: 'img',
      descSelector: '.info',
    ),
    AnimeSource(
      name: '风车动漫',
      baseUrl: 'https://www.dmdmz.com',
      searchPath: '/search?keyword={query}',
      resultSelector: '.module-item',
      titleSelector: '.title',
      linkSelector: 'a[href]',
      coverSelector: 'img',
      descSelector: '.description',
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

  const VideoSource({
    required this.name,
    required this.baseUrl,
    required this.searchPath,
    required this.resultSelector,
    required this.titleSelector,
    required this.linkSelector,
    required this.coverSelector,
    required this.descSelector,
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

  const AnimeSource({
    required this.name,
    required this.baseUrl,
    required this.searchPath,
    required this.resultSelector,
    required this.titleSelector,
    required this.linkSelector,
    required this.coverSelector,
    required this.descSelector,
  });

  String getSearchUrl(String query) {
    return '$baseUrl${searchPath.replaceAll('{query}', Uri.encodeComponent(query))}';
  }
}
