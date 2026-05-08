import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/utils/html_parser.dart';

/// 解析播放源
/// MacCMS 站点需要两步解析：详情页 → 播放页 → m3u8 URL
class SourceResolver {
  final ApiClient _apiClient;

  SourceResolver(this._apiClient);

  /// 解析播放地址
  /// 返回播放源列表 [PlaySource]，包含剧集信息
  Future<List<PlaySource>> resolve(String detailUrl) async {
    try {
      final html = await _apiClient.fetchHtml(detailUrl);

      // 第一步：尝试 MacCMS 两步解析（详情页 → 播放页）
      final episodes = _parseEpisodes(html, detailUrl);
      if (episodes.isNotEmpty) {
        final sources = await _resolvePlayPages(episodes);
        if (sources.isNotEmpty) return sources;
      }

      // Fallback：直接从详情页提取视频链接
      final sources = _extractSourcesFromPage(html);

      // 去重
      final seen = <String>{};
      return sources.where((s) => seen.add(s.url)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 从详情页解析剧集列表
  List<EpisodeInfo> _parseEpisodes(String html, String detailUrl) {
    final episodes = <EpisodeInfo>[];
    final uri = Uri.parse(detailUrl);
    final base = '${uri.scheme}://${uri.host}';

    // MacCMS 播放页链接格式: /index.php/vod/play/id/xxx/sid/xxx/nid/xxx.html
    final playPattern = RegExp(r'href="(/index\.php/vod/play/id/\d+/sid/\d+/nid/\d+\.html)"[^>]*>([^<]+)');
    for (final match in playPattern.allMatches(html)) {
      final path = match.group(1)!;
      final title = match.group(2)!.trim();
      if (title.isEmpty) continue;

      final url = '$base$path';
      if (!episodes.any((e) => e.url == url)) {
        episodes.add(EpisodeInfo(title: title, url: url));
      }
    }

    // 通用格式: /vod/play/id/xxx/sid/xxx/nid/xxx.html（无 index.php）
    if (episodes.isEmpty) {
      final altPattern = RegExp(r'href="(/vod/play/id/\d+/sid/\d+/nid/\d+\.html)"[^>]*>([^<]+)');
      for (final match in altPattern.allMatches(html)) {
        final path = match.group(1)!;
        final title = match.group(2)!.trim();
        if (title.isEmpty) continue;

        final url = '$base$path';
        if (!episodes.any((e) => e.url == url)) {
          episodes.add(EpisodeInfo(title: title, url: url));
        }
      }
    }

    // 尝试从播放源容器中提取（更精准）
    if (episodes.isEmpty) {
      final containers = HtmlUtil.extractAll(html, '.content-slide, .playlist, .play_list, .stui-content__playlist');
      for (final container in containers) {
        final links = container.querySelectorAll('a');
        for (final link in links) {
          var href = link.attributes['href'] ?? '';
          final title = link.text.trim();
          if (title.isEmpty || href.isEmpty) continue;

          if (!href.startsWith('http')) {
            href = '$base$href';
          }

          // 只保留播放页链接
          if (href.contains('/play/') && !episodes.any((e) => e.url == href)) {
            episodes.add(EpisodeInfo(title: title, url: href));
          }
        }
      }
    }

    return episodes;
  }

  /// 批量解析播放页，提取 m3u8/mp4 URL
  Future<List<PlaySource>> _resolvePlayPages(List<EpisodeInfo> episodes) async {
    final sources = <PlaySource>[];

    // 并发请求，但限制并发数避免被封
    const batchSize = 5;
    for (var i = 0; i < episodes.length; i += batchSize) {
      final batch = episodes.sublist(i, (i + batchSize).clamp(0, episodes.length));
      final futures = batch.map((ep) => _resolvePlayPage(ep));
      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) sources.add(result);
      }
    }

    return sources;
  }

  /// 解析单个播放页，提取视频 URL
  Future<PlaySource?> _resolvePlayPage(EpisodeInfo episode) async {
    try {
      final html = await _apiClient.fetchHtml(episode.url);

      // MacCMS 播放页通常有 player_aaaa = {url: "...", ...} 配置
      final playerPatterns = [
        RegExp(r'var\s+player_aaaa\s*=\s*(\{[^}]+\})'),
        RegExp(r'var\s+player_\w+\s*=\s*(\{[^}]+\})'),
        RegExp(r'"url"\s*:\s*"(https?://[^"]+\.(?:m3u8|mp4)[^"]*)"'),
      ];

      for (final pattern in playerPatterns) {
        final match = pattern.firstMatch(html);
        if (match == null) continue;

        final group1 = match.group(1)!;

        // 如果匹配到 JSON 对象，解析其中的 url
        if (group1.startsWith('{')) {
          try {
            // 处理可能的非标准 JSON（单引号、无引号 key）
            var jsonStr = group1
                .replaceAll("'", '"')
                .replaceAll(RegExp(r'(\w+)\s*:'), r'"\1":');
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            final url = json['url'] as String?;
            if (url != null && url.isNotEmpty && url.startsWith('http')) {
              return PlaySource(
                url: url,
                quality: episode.title,
                type: _detectType(url),
                episodeTitle: episode.title,
              );
            }
          } catch (_) {
            // JSON 解析失败，尝试正则提取
          }
        }

        // 如果直接匹配到 URL
        if (group1.startsWith('http')) {
          return PlaySource(
            url: group1,
            quality: episode.title,
            type: _detectType(group1),
            episodeTitle: episode.title,
          );
        }
      }

      // Fallback：通用 m3u8/mp4 提取
      final sources = _extractSourcesFromPage(html);
      if (sources.isNotEmpty) {
        final first = sources.first;
        return PlaySource(
          url: first.url,
          quality: episode.title,
          type: first.type,
          episodeTitle: episode.title,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 从页面 HTML 中提取视频链接（通用方法）
  List<PlaySource> _extractSourcesFromPage(String html) {
    final sources = <PlaySource>[];

    // 方式1: 从 JavaScript 中提取 m3u8 链接
    final m3u8Patterns = [
      RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*'),
      RegExp(r'"url"\s*:\s*"(https?://[^"]+\.m3u8[^"]*)"'),
    ];
    for (final pattern in m3u8Patterns) {
      for (final match in pattern.allMatches(html)) {
        final url = match.group(1) ?? match.group(0);
        if (url != null && url.isNotEmpty) {
          sources.add(PlaySource(url: url, quality: 'HLS', type: PlaySourceType.hls));
        }
      }
    }

    // 方式2: 从 JavaScript 中提取 mp4 链接
    if (sources.isEmpty) {
      final mp4Patterns = [
        RegExp(r'https?://[^\s"<>]+\.mp4[^\s"<>]*'),
        RegExp(r'"url"\s*:\s*"(https?://[^"]+\.mp4[^"]*)"'),
      ];
      for (final pattern in mp4Patterns) {
        for (final match in pattern.allMatches(html)) {
          final url = match.group(1) ?? match.group(0);
          if (url != null && url.isNotEmpty) {
            sources.add(PlaySource(url: url, quality: 'MP4', type: PlaySourceType.mp4));
          }
        }
      }
    }

    // 方式3: 提取 <video>/<source> 标签
    if (sources.isEmpty) {
      final videoElements = HtmlUtil.extractAll(html, 'video source, video');
      for (final el in videoElements) {
        final src = el.attributes['src'];
        if (src != null && src.isNotEmpty && src.startsWith('http')) {
          sources.add(PlaySource(
            url: src,
            quality: el.attributes['label'] ?? '默认',
            type: _detectType(src),
          ));
        }
      }
    }

    // 方式4: 提取 iframe
    if (sources.isEmpty) {
      final iframes = HtmlUtil.extractAll(html, 'iframe');
      for (final iframe in iframes) {
        final src = iframe.attributes['src'];
        if (src != null && src.isNotEmpty && _isVideoUrl(src)) {
          sources.add(PlaySource(url: src, quality: '嵌入', type: PlaySourceType.embed));
        }
      }
    }

    return sources;
  }

  PlaySourceType _detectType(String url) {
    if (url.contains('.m3u8')) return PlaySourceType.hls;
    if (url.contains('.mp4')) return PlaySourceType.mp4;
    if (url.contains('.mp3') || url.contains('.aac') || url.contains('.ogg')) {
      return PlaySourceType.audio;
    }
    if (url.contains('player') || url.contains('embed')) {
      return PlaySourceType.embed;
    }
    return PlaySourceType.unknown;
  }

  bool _isVideoUrl(String url) {
    return url.contains('player') ||
        url.contains('embed') ||
        url.contains('video') ||
        url.contains('.m3u8') ||
        url.contains('.mp4') ||
        url.contains('.flv') ||
        url.contains('.ts');
  }
}

enum PlaySourceType { mp4, hls, embed, audio, unknown }

class PlaySource {
  final String url;
  final String quality;
  final PlaySourceType type;
  final String? episodeTitle;

  const PlaySource({
    required this.url,
    required this.quality,
    required this.type,
    this.episodeTitle,
  });
}

class EpisodeInfo {
  final String title;
  final String url;

  const EpisodeInfo({required this.title, required this.url});
}
