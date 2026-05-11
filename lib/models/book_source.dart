import 'dart:convert';

class BookSource {
  final String bookSourceName;
  final String bookSourceUrl;
  final String bookSourceGroup;
  final int bookSourceType;
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

  String getSearchUrl(String query, {int page = 1}) {
    var url = searchUrl
        .replaceAll('{{key}}', Uri.encodeComponent(query))
        .replaceAll('{{page}}', page.toString());

    if (url.contains(',{')) {
      url = url.split(',{').first;
    }

    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$bookSourceUrl$url';
    return '$bookSourceUrl/$url';
  }

  bool get isPostSearch {
    if (!searchUrl.contains(',{')) return false;
    final optionsStr = searchUrl.substring(searchUrl.indexOf(',{'));
    return optionsStr.contains('"method"') && optionsStr.toUpperCase().contains('POST');
  }

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

class RuleSearch {
  final String bookList;
  final String name;
  final String author;
  final String bookUrl;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;

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

  Map<String, dynamic> toJson() => {
    'bookList': bookList, 'name': name, 'author': author, 'bookUrl': bookUrl,
    'coverUrl': coverUrl, 'intro': intro, 'kind': kind, 'lastChapter': lastChapter,
  };
}

class RuleBookInfo {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;
  final String tocUrl;

  const RuleBookInfo({
    this.name = '', this.author = '', this.coverUrl = '', this.intro = '',
    this.kind = '', this.lastChapter = '', this.tocUrl = '',
  });

  factory RuleBookInfo.fromJson(Map<String, dynamic> json) {
    return RuleBookInfo(
      name: json['name'] as String? ?? '', author: json['author'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '', intro: json['intro'] as String? ?? '',
      kind: json['kind'] as String? ?? '', lastChapter: json['lastChapter'] as String? ?? '',
      tocUrl: json['tocUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name, 'author': author, 'coverUrl': coverUrl, 'intro': intro,
    'kind': kind, 'lastChapter': lastChapter, 'tocUrl': tocUrl,
  };
}

class RuleToc {
  final String chapterList;
  final String chapterName;
  final String chapterUrl;
  final String nextTocUrl;

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

  Map<String, dynamic> toJson() => {
    'chapterList': chapterList, 'chapterName': chapterName,
    'chapterUrl': chapterUrl, 'nextTocUrl': nextTocUrl,
  };
}

class RuleContent {
  final String content;
  final String replaceRegex;
  final String nextContentUrl;

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

  Map<String, dynamic> toJson() => {
    'content': content, 'replaceRegex': replaceRegex, 'nextContentUrl': nextContentUrl,
  };
}

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
    this.name = '', this.author = '', required this.bookUrl,
    this.coverUrl = '', this.intro = '', this.kind = '', this.lastChapter = '',
  });

  factory RuleExplore.fromJson(Map<String, dynamic> json) {
    return RuleExplore(
      bookList: json['bookList'] as String? ?? '', name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '', bookUrl: json['bookUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '', intro: json['intro'] as String? ?? '',
      kind: json['kind'] as String? ?? '', lastChapter: json['lastChapter'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'bookList': bookList, 'name': name, 'author': author, 'bookUrl': bookUrl,
    'coverUrl': coverUrl, 'intro': intro, 'kind': kind, 'lastChapter': lastChapter,
  };
}

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
