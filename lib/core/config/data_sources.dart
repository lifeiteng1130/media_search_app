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

  // 小说资源已迁移至规则化书源系统（BookSourceRepository）

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
