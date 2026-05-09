import 'dart:convert';

/// 书源模型 - 兼容 Legado（开源阅读）格式
class BookSource {
  final String bookSourceName;
  final String bookSourceUrl;
  final String bookSourceGroup;
  final int bookSourceType; // 0=文本, 1=音频
  final bool enabled;
  final bool enabledExplore;
  final String searchUrl;
  final String? header;
  final int weight;
  final RuleSearch? ruleSearch;
  final RuleBookInfo? ruleBookInfo;
  final RuleToc? ruleToc;
  final RuleContent? ruleContent;
  final RuleExplore? ruleExplore;
  final String? exploreUrl;

  const BookSource({
    required this.bookSourceName,
    required this.bookSourceUrl,
    this.bookSourceGroup = '',
    this.bookSourceType = 0,
    this.enabled = true,
    this.enabledExplore = false,
    required this.searchUrl,
    this.header,
    this.weight = 0,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.ruleExplore,
    this.exploreUrl,
  });

  /// 构建搜索 URL
  String getSearchUrl(String query, {int page = 1}) {
    var url = searchUrl
        .replaceAll('{{key}}', Uri.encodeComponent(query))
        .replaceAll('{{page}}', page.toString());

    // 处理 POST 格式: "/path,{method:POST,body:key={{key}}}"
    if (url.contains(',{')) {
      url = url.split(',{').first;
    }

    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$bookSourceUrl$url';
    return '$bookSourceUrl/$url';
  }

  /// 是否为 POST 搜索
  bool get isPostSearch {
    if (!searchUrl.contains(',{')) return false;
    final optionsStr = searchUrl.substring(searchUrl.indexOf(',{'));
    return optionsStr.contains('"method"') && optionsStr.toUpperCase().contains('POST');
  }

  /// 获取 POST body
  Map<String, String> getSearchBody(String query, {int page = 1}) {
    if (!isPostSearch) return {};
    final optionsStr = searchUrl.substring(searchUrl.indexOf(',{'));
    final bodyMatch = RegExp(r'"body"\s*:\s*"([^"]*)"').firstMatch(optionsStr);
    if (bodyMatch == null) return {};
    final body = bodyMatch.group(1)!
        .replaceAll('{{key}}', query)
        .replaceAll('{{page}}', page.toString());
    final params = <String, String>{};
    for (final pair in body.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        params[parts[0]] = parts[1];
      }
    }
    return params;
  }

  factory BookSource.fromJson(Map<String, dynamic> json) {
    return BookSource(
      bookSourceName: json['bookSourceName'] as String? ?? '',
      bookSourceUrl: json['bookSourceUrl'] as String? ?? '',
      bookSourceGroup: json['bookSourceGroup'] as String? ?? '',
      bookSourceType: json['bookSourceType'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      enabledExplore: json['enabledExplore'] as bool? ?? false,
      searchUrl: json['searchUrl'] as String? ?? '',
      header: json['header'] as String?,
      weight: json['weight'] as int? ?? 0,
      ruleSearch: json['ruleSearch'] != null
          ? RuleSearch.fromJson(Map<String, dynamic>.from(json['ruleSearch']))
          : null,
      ruleBookInfo: json['ruleBookInfo'] != null
          ? RuleBookInfo.fromJson(Map<String, dynamic>.from(json['ruleBookInfo']))
          : null,
      ruleToc: json['ruleToc'] != null
          ? RuleToc.fromJson(Map<String, dynamic>.from(json['ruleToc']))
          : null,
      ruleContent: json['ruleContent'] != null
          ? RuleContent.fromJson(Map<String, dynamic>.from(json['ruleContent']))
          : null,
      ruleExplore: json['ruleExplore'] != null
          ? RuleExplore.fromJson(Map<String, dynamic>.from(json['ruleExplore']))
          : null,
      exploreUrl: json['exploreUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookSourceName': bookSourceName,
      'bookSourceUrl': bookSourceUrl,
      'bookSourceGroup': bookSourceGroup,
      'bookSourceType': bookSourceType,
      'enabled': enabled,
      'enabledExplore': enabledExplore,
      'searchUrl': searchUrl,
      if (header != null) 'header': header,
      'weight': weight,
      if (ruleSearch != null) 'ruleSearch': ruleSearch!.toJson(),
      if (ruleBookInfo != null) 'ruleBookInfo': ruleBookInfo!.toJson(),
      if (ruleToc != null) 'ruleToc': ruleToc!.toJson(),
      if (ruleContent != null) 'ruleContent': ruleContent!.toJson(),
      if (ruleExplore != null) 'ruleExplore': ruleExplore!.toJson(),
      if (exploreUrl != null) 'exploreUrl': exploreUrl,
    };
  }

  BookSource copyWith({bool? enabled}) {
    return BookSource(
      bookSourceName: bookSourceName,
      bookSourceUrl: bookSourceUrl,
      bookSourceGroup: bookSourceGroup,
      bookSourceType: bookSourceType,
      enabled: enabled ?? this.enabled,
      enabledExplore: enabledExplore,
      searchUrl: searchUrl,
      header: header,
      weight: weight,
      ruleSearch: ruleSearch,
      ruleBookInfo: ruleBookInfo,
      ruleToc: ruleToc,
      ruleContent: ruleContent,
      ruleExplore: ruleExplore,
      exploreUrl: exploreUrl,
    );
  }
}

/// 搜索结果解析规则
class RuleSearch {
  final String bookList;    // 结果列表 CSS 选择器
  final String name;        // 书名规则
  final String author;      // 作者规则
  final String bookUrl;     // 详情页链接规则
  final String coverUrl;    // 封面图规则
  final String intro;       // 简介规则
  final String kind;        // 分类规则
  final String lastChapter; // 最新章节规则

  const RuleSearch({
    required this.bookList,
    required this.name,
    this.author = '',
    required this.bookUrl,
    this.coverUrl = '',
    this.intro = '',
    this.kind = '',
    this.lastChapter = '',
  });

  factory RuleSearch.fromJson(Map<String, dynamic> json) {
    return RuleSearch(
      bookList: json['bookList'] as String? ?? '',
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      bookUrl: json['bookUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      lastChapter: json['lastChapter'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookList': bookList,
      'name': name,
      'author': author,
      'bookUrl': bookUrl,
      'coverUrl': coverUrl,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
    };
  }
}

/// 书籍详情页解析规则
class RuleBookInfo {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;
  final String tocUrl; // 独立目录页 URL 规则

  const RuleBookInfo({
    this.name = '',
    this.author = '',
    this.coverUrl = '',
    this.intro = '',
    this.kind = '',
    this.lastChapter = '',
    this.tocUrl = '',
  });

  factory RuleBookInfo.fromJson(Map<String, dynamic> json) {
    return RuleBookInfo(
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      lastChapter: json['lastChapter'] as String? ?? '',
      tocUrl: json['tocUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'author': author,
      'coverUrl': coverUrl,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
      'tocUrl': tocUrl,
    };
  }
}

/// 章节目录解析规则
class RuleToc {
  final String chapterList;   // 章节列表 CSS 选择器
  final String chapterName;   // 章节名规则
  final String chapterUrl;    // 章节链接规则
  final String nextTocUrl;    // 下一页目录 URL

  const RuleToc({
    required this.chapterList,
    this.chapterName = 'text',
    this.chapterUrl = 'href',
    this.nextTocUrl = '',
  });

  factory RuleToc.fromJson(Map<String, dynamic> json) {
    return RuleToc(
      chapterList: json['chapterList'] as String? ?? '',
      chapterName: json['chapterName'] as String? ?? 'text',
      chapterUrl: json['chapterUrl'] as String? ?? 'href',
      nextTocUrl: json['nextTocUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chapterList': chapterList,
      'chapterName': chapterName,
      'chapterUrl': chapterUrl,
      'nextTocUrl': nextTocUrl,
    };
  }
}

/// 章节内容解析规则
class RuleContent {
  final String content;        // 内容 CSS 选择器
  final String replaceRegex;   // 清理正则
  final String nextContentUrl; // 下一页 URL

  const RuleContent({
    required this.content,
    this.replaceRegex = '',
    this.nextContentUrl = '',
  });

  factory RuleContent.fromJson(Map<String, dynamic> json) {
    return RuleContent(
      content: json['content'] as String? ?? '',
      replaceRegex: json['replaceRegex'] as String? ?? '',
      nextContentUrl: json['nextContentUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'replaceRegex': replaceRegex,
      'nextContentUrl': nextContentUrl,
    };
  }
}

/// 发现/排行榜解析规则
class RuleExplore {
  final String bookList;
  final String name;
  final String author;
  final String bookUrl;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;

  const RuleExplore({
    required this.bookList,
    this.name = '',
    this.author = '',
    required this.bookUrl,
    this.coverUrl = '',
    this.intro = '',
    this.kind = '',
    this.lastChapter = '',
  });

  factory RuleExplore.fromJson(Map<String, dynamic> json) {
    return RuleExplore(
      bookList: json['bookList'] as String? ?? '',
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      bookUrl: json['bookUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      lastChapter: json['lastChapter'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookList': bookList,
      'name': name,
      'author': author,
      'bookUrl': bookUrl,
      'coverUrl': coverUrl,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
    };
  }
}

/// 批量导入书源 JSON 解析
List<BookSource> parseBookSourcesJson(String jsonStr) {
  final List<dynamic> list;
  try {
    list = jsonDecode(jsonStr) as List;
  } catch (e) {
    return [];
  }
  return list
      .map((e) {
        try {
          return BookSource.fromJson(Map<String, dynamic>.from(e));
        } catch (_) {
          return null;
        }
      })
      .where((s) => s != null && s.bookSourceUrl.isNotEmpty && s.searchUrl.isNotEmpty)
      .cast<BookSource>()
      .toList();
}
