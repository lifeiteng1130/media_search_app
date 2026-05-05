import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../search/data/models/media_item.dart';
import '../data/player_repository.dart';
import '../data/source_resolver.dart';
import '../../../core/network/api_client.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ApiClient());
});

final playSourcesProvider = FutureProvider.family<List<PlaySource>, MediaItem>((ref, item) async {
  final repo = ref.read(playerRepositoryProvider);
  return repo.getPlaySources(item);
});

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem item;
  const VideoPlayerScreen({super.key, required this.item});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  PlaySource? _currentSource;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _loadPlayHistory();
  }

  @override
  void dispose() {
    _savePlayHistory();
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  Future<void> _loadPlayHistory() async {
    try {
      final box = await Hive.openBox('play_history');
      final history = box.get(widget.item.detailUrl);
      if (history != null && mounted) {
        final data = Map<String, dynamic>.from(history);
        // 可以恢复上次播放位置
      }
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _savePlayHistory() async {
    try {
      final box = await Hive.openBox('play_history');
      await box.put(widget.item.detailUrl, {
        'title': widget.item.title,
        'coverUrl': widget.item.coverUrl,
        'detailUrl': widget.item.detailUrl,
        'source': _currentSource?.quality,
        'position': _videoController?.value.position.inSeconds,
        'lastPlayTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _initPlayer(PlaySource source) async {
    _chewieController?.dispose();
    _videoController?.dispose();

    setState(() {
      _currentSource = source;
    });

    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(source.url),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': source.url,
        },
      );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  '播放失败: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _initPlayer(source),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        },
      );

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(playSourcesProvider(widget.item));

    if (_isFullscreen) {
      return _buildFullscreenPlayer(sourcesAsync);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.screen_rotation),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
      body: Column(
        children: [
          // 视频播放器
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _chewieController != null
                ? Chewie(controller: _chewieController!)
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
                          SizedBox(height: 8),
                          Text('选择播放源开始播放', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  ),
          ),

          // 影视信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (widget.item.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.item.description!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const Divider(),

          // 播放源列表
          Expanded(
            child: sourcesAsync.when(
              data: (sources) {
                if (sources.isEmpty) {
                  return const Center(child: Text('暂无可用播放源'));
                }
                return _buildSourceList(sources);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载播放源失败: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenPlayer(AsyncValue<List<PlaySource>> sourcesAsync) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _toggleFullscreen,
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.screen_rotation, color: Colors.white),
              onPressed: _toggleFullscreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceList(List<PlaySource> sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('播放源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              final isActive = _currentSource?.url == source.url;
              return ListTile(
                leading: Icon(
                  _sourceIcon(source.type),
                  color: isActive ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(source.quality),
                subtitle: Text(
                  source.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isActive
                    ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
                    : null,
                selected: isActive,
                onTap: () => _initPlayer(source),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _sourceIcon(PlaySourceType type) {
    switch (type) {
      case PlaySourceType.hls:
        return Icons.stream;
      case PlaySourceType.mp4:
        return Icons.videocam;
      case PlaySourceType.embed:
        return Icons.web;
      case PlaySourceType.audio:
        return Icons.audiotrack;
      default:
        return Icons.play_circle;
    }
  }
}
