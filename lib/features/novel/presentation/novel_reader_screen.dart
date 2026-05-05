import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../search/data/models/media_item.dart';
import '../data/novel_repository.dart';
import '../data/novel_download_service.dart';
import '../../../core/network/api_client.dart';

final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  return NovelRepository(ApiClient());
});

final chaptersProvider = FutureProvider.family<List<NovelChapter>, MediaItem>((ref, item) async {
  if (item.detailUrl == null) return [];
  final repo = ref.read(novelRepositoryProvider);
  return repo.getChapters(item.detailUrl!);
});

final chapterContentProvider = FutureProvider.family<String, NovelChapter>((ref, chapter) async {
  final repo = ref.read(novelRepositoryProvider);
  return repo.getChapterContent(chapter.url);
});

class NovelReaderScreen extends ConsumerStatefulWidget {
  final MediaItem item;
  const NovelReaderScreen({super.key, required this.item});

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen> {
  NovelChapter? _currentChapter;
  double _fontSize = 16;
  double _lineHeight = 1.8;
  bool _showControls = false;
  final _downloadService = NovelDownloadService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  int _downloadedChapters = 0;
  int _totalChapters = 0;

  @override
  void initState() {
    super.initState();
    _loadReadingProgress();
  }

  Future<void> _loadReadingProgress() async {
    try {
      final box = await Hive.openBox('read_history');
      final progress = box.get(widget.item.detailUrl);
      if (progress != null && mounted) {
        final data = Map<String, dynamic>.from(progress);
        // 恢复阅读进度会在章节加载后处理
      }
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _saveReadingProgress(NovelChapter chapter) async {
    try {
      final box = await Hive.openBox('read_history');
      await box.put(widget.item.detailUrl, {
        'title': widget.item.title,
        'chapterTitle': chapter.title,
        'chapterIndex': chapter.index,
        'chapterUrl': chapter.url,
        'lastReadTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _startDownload(List<NovelChapter> chapters) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadedChapters = 0;
      _totalChapters = chapters.length;
    });

    try {
      await _downloadService.downloadNovel(
        title: widget.item.title,
        author: widget.item.description ?? '',
        coverUrl: widget.item.coverUrl ?? '',
        detailUrl: widget.item.detailUrl ?? '',
        chapters: chapters,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _downloadedChapters = current;
              _totalChapters = total;
              _downloadProgress = current / total;
            });
          }
        },
        onChapterComplete: (chapterTitle) {
          // 可以显示下载进度
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.item));

    return Scaffold(
      appBar: _showControls
          ? AppBar(
              title: Text(_currentChapter?.title ?? widget.item.title),
              actions: [
                // 下载按钮
                if (!_isDownloading)
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      chaptersAsync.whenData((chapters) {
                        if (chapters.isNotEmpty) {
                          _startDownload(chapters);
                        }
                      });
                    },
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: _downloadProgress,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                // 字体大小
                IconButton(
                  icon: const Icon(Icons.text_decrease),
                  onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(12, 24)),
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase),
                  onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(12, 24)),
                ),
                // 章节列表
                IconButton(
                  icon: const Icon(Icons.list),
                  onPressed: () => _showChapterDrawer(chaptersAsync),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: chaptersAsync.when(
          data: (chapters) {
            if (chapters.isEmpty) {
              return const Center(child: Text('暂无章节'));
            }
            if (_currentChapter == null) {
              _currentChapter = chapters.first;
              _saveReadingProgress(_currentChapter!);
            }
            return _buildReader(_currentChapter!);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ),
    );
  }

  Widget _buildReader(NovelChapter chapter) {
    final contentAsync = ref.watch(chapterContentProvider(chapter));

    return contentAsync.when(
      data: (content) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.title,
                style: TextStyle(
                  fontSize: _fontSize + 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                content,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: _lineHeight,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 40),
              _buildChapterNavigation(chapter),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载章节内容失败: $e')),
    );
  }

  Widget _buildChapterNavigation(NovelChapter current) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.item));
    return chaptersAsync.when(
      data: (chapters) {
        final index = chapters.indexOf(current);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (index > 0)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _currentChapter = chapters[index - 1]);
                  _saveReadingProgress(chapters[index - 1]);
                },
                icon: const Icon(Icons.chevron_left),
                label: const Text('上一章'),
              )
            else
              const SizedBox(),
            Text('${index + 1}/${chapters.length}'),
            if (index < chapters.length - 1)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _currentChapter = chapters[index + 1]);
                  _saveReadingProgress(chapters[index + 1]);
                },
                icon: const Icon(Icons.chevron_right),
                label: const Text('下一章'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              )
            else
              const SizedBox(),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  void _showChapterDrawer(AsyncValue<List<NovelChapter>> chaptersAsync) {
    chaptersAsync.whenData((chapters) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('目录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${chapters.length}章', style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final isCurrent = chapter == _currentChapter;
                        return ListTile(
                          title: Text(
                            chapter.title,
                            style: TextStyle(
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontWeight: isCurrent ? FontWeight.bold : null,
                            ),
                          ),
                          trailing: isCurrent ? const Icon(Icons.check) : null,
                          onTap: () {
                            setState(() => _currentChapter = chapter);
                            _saveReadingProgress(chapter);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }
}
