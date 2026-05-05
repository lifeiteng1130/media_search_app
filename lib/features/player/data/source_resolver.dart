import '../../../core/network/api_client.dart';
import '../../../core/utils/html_parser.dart';

/// 解析播放源，从详情页提取视频直链或 m3u8 地址
class SourceResolver {
  final ApiClient _apiClient;

  SourceResolver(this._apiClient);

  /// 解析播放地址
  /// 返回播放源列表 [PlaySource]
  Future<List<PlaySource>> resolve(String detailUrl) async {
    try {
      final html = await _apiClient.fetchHtml(detailUrl);
      final sources = _extractSources(html);

      // 去重
      final seen = <String>{};
      final unique = sources.where((s) => seen.add(s.url)).toList();

      return unique;
    } catch (e) {
      return [];
    }
  }

  List<PlaySource> _extractSources(String html) {
    final sources = <PlaySource>[];

    // 方式1: 提取 <video> 或 <source> 标签
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

    // 方式2: 从 JavaScript 中提取 m3u8 链接
    final m3u8Patterns = [
      RegExp(r'https?://[^\s"\'<>]+\.m3u8[^\s"\'<>]*'),
      RegExp(r'"url"\s*:\s*"(https?://[^"]+\.m3u8[^"]*)"'),
      RegExp(r'var\s+\w+\s*=\s*"(https?://[^"]+\.m3u8[^"]*)"'),
    ];

    for (final pattern in m3u8Patterns) {
      for (final match in pattern.allMatches(html)) {
        final url = match.group(1) ?? match.group(0);
        if (url != null && url.isNotEmpty) {
          sources.add(PlaySource(
            url: url,
            quality: 'HLS',
            type: PlaySourceType.hls,
          ));
        }
      }
    }

    // 方式3: 从 JavaScript 中提取 mp4 链接
    final mp4Patterns = [
      RegExp(r'https?://[^\s"\'<>]+\.mp4[^\s"\'<>]*'),
      RegExp(r'"url"\s*:\s*"(https?://[^"]+\.mp4[^"]*)"'),
      RegExp(r'var\s+\w+\s*=\s*"(https?://[^"]+\.mp4[^"]*)"'),
    ];

    for (final pattern in mp4Patterns) {
      for (final match in pattern.allMatches(html)) {
        final url = match.group(1) ?? match.group(0);
        if (url != null && url.isNotEmpty) {
          sources.add(PlaySource(
            url: url,
            quality: 'MP4',
            type: PlaySourceType.mp4,
          ));
        }
      }
    }

    // 方式4: 提取 iframe 嵌入的播放器
    final iframes = HtmlUtil.extractAll(html, 'iframe');
    for (final iframe in iframes) {
      final src = iframe.attributes['src'];
      if (src != null && src.isNotEmpty && _isVideoUrl(src)) {
        sources.add(PlaySource(
          url: src,
          quality: '嵌入',
          type: PlaySourceType.embed,
        ));
      }
    }

    // 方式5: 提取 data-src 属性
    final dataSrcElements = HtmlUtil.extractAll(html, '[data-src]');
    for (final el in dataSrcElements) {
      final src = el.attributes['data-src'];
      if (src != null && src.isNotEmpty && _isVideoUrl(src)) {
        sources.add(PlaySource(
          url: src,
          quality: '视频',
          type: _detectType(src),
        ));
      }
    }

    // 方式6: 提取 JSON 配置中的视频源
    final jsonPattern = RegExp(r'\"(?:url|src|file|video_url)\"\s*:\s*\"(https?://[^\"]+)\"');
    for (final match in jsonPattern.allMatches(html)) {
      final url = match.group(1);
      if (url != null && _isVideoUrl(url)) {
        sources.add(PlaySource(
          url: url,
          quality: '视频',
          type: _detectType(url),
        ));
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

  const PlaySource({required this.url, required this.quality, required this.type});
}
