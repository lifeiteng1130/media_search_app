import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../search/data/models/media_item.dart';
import '../../favorites/presentation/favorites_provider.dart';
import '../data/novel_repository.dart';
import '../data/book_source.dart';
import '../data/book_source_repository.dart';
import '../data/reader_settings.dart';
import '../data/novel_download_service.dart';
import '../../../core/network/api_client.dart';
import 'reader_settings_sheet.dart';

final bookSourceRepositoryProvider = Provider<BookSourceRepository>((ref) {
  return BookSourceRepository(ApiClient());
});

final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  return NovelRepository(ApiClient(), ref.read(bookSourceRepositoryProvider));
});

class ChaptersResult {
  final List<NovelChapter> chapters;
  final BookSource source;
  const ChaptersResult(this.chapters, this.source);
}

final _emptySource = BookSource(bookSourceName: '', bookSourceUrl: '', searchUrl: '');

final chaptersProvider = FutureProvider.family<ChaptersResult, MediaItem>((ref, item) async {
  if (item.detailUrl == null) return ChaptersResult([], _emptySource);
  final repo = ref.read(novelRepositoryProvider);
  final sourceRepo = ref.read(bookSourceRepositoryProvider);
  BookSource? source;
  if (item.bookSourceUrl != null) {
    source = await sourceRepo.findByUrl(item.bookSourceUrl!);
  }
  source ??= await sourceRepo.findByUrl(item.detailUrl!);
  if (source == null) return ChaptersResult([], _emptySource);
  final chapters = await repo.getChapters(item.detailUrl!, source);
  return ChaptersResult(chapters, source);
});

class ChapterWithSource {
  final NovelChapter chapter;
  final BookSource source;
  const ChapterWithSource(this.chapter, this.source);
}

final chapterContentProvider = FutureProvider.family<String, ChapterWithSource>((ref, cws) async {
  final repo = ref.read(novelRepositoryProvider);
  return repo.getChapterContent(cws.chapter.url, cws.source);
});

class NovelReaderScreen extends ConsumerStatefulWidget {
  final MediaItem item;
  const NovelReaderScreen({super.key, required this.item});

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen>
    with SingleTickerProviderStateMixin {
  // 状态
  NovelChapter? _currentChapter;
  BookSource? _bookSource;
  ReaderSettings _settings = ReaderSettings();
  bool _showControls = false;
  bool _settingsLoaded = false;

  // 翻页
  PageController? _pageController;
  List<String> _pages = [];
  int _currentPage = 0;

  // 下载
  final _downloadService = NovelDownloadService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  int _downloadedChapters = 0;
  int _totalChapters = 0;

  // 阅读进度
  int? _savedChapterIndex;

  // 控制栏动画
  late AnimationController _controlsAnimController;
  late Animation<Offset> _topBarAnimation;
  late Animation<Offset> _bottomBarAnimation;

  @override
  void initState() {
    super.initState();
    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _topBarAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controlsAnimController, curve: Curves.easeOut));
    _bottomBarAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controlsAnimController, curve: Curves.easeOut));

    _loadSettings();
    _loadReadingProgress();
    _enterImmersive();
  }

  @override
  void dispose() {
    _controlsAnimController.dispose();
    _pageController?.dispose();
    _exitImmersive();
    super.dispose();
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _loadSettings() async {
    final settings = await ReaderSettings.load();
    if (mounted) {
      setState(() {
        _settings = settings;
        _settingsLoaded = true;
      });
    }
  }

  Future<void> _saveSettings() async {
    await _settings.save();
  }

  Future<void> _loadReadingProgress() async {
    try {
      final box = await Hive.openBox('read_history');
      final progress = box.get(widget.item.detailUrl);
      if (progress != null && mounted) {
        final data = Map<String, dynamic>.from(progress);
        _savedChapterIndex = data['chapterIndex'] as int?;
      }
    } catch (_) {}
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
    } catch (_) {}
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsAnimController.forward();
    } else {
      _controlsAnimController.reverse();
    }
  }

  // ========== 分页引擎 ==========

  void _paginateContent(String content) {
    if (!_settings.pageMode) return;

    final mq = MediaQuery.of(context);
    final maxWidth = mq.size.width - _settings.horizontalMargin * 2;
    final maxHeight = mq.size.height - mq.padding.top - mq.padding.bottom - 40; // 留一点缓冲

    _pages = _paginateText(content, maxWidth, maxHeight, _settings.textStyle);

    if (_pageController != null) {
      _pageController!.dispose();
    }
    _pageController = PageController();
    _currentPage = 0;
  }

  List<String> _paginateText(String text, double maxWidth, double maxHeight, TextStyle style) {
    final paragraphs = text.split('\n');
    final pages = <String>[];
    var currentPageLines = <String>[];
    var currentHeight = 0.0;
    final lineSpacing = style.fontSize! * (style.height ?? 1.0);

    for (final paragraph in paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) {
        currentHeight += lineSpacing * 0.5;
        if (currentHeight >= maxHeight) {
          if (currentPageLines.isNotEmpty) {
            pages.add(currentPageLines.join('\n'));
            currentPageLines = [];
          }
          currentHeight = 0;
        }
        continue;
      }

      // 计算这段文字需要的高度
      final tp = TextPainter(
        text: TextSpan(text: trimmed, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: maxWidth);

      if (currentHeight + tp.height > maxHeight && currentPageLines.isNotEmpty) {
        // 当前页放不下，需要切分
        final remainingHeight = maxHeight - currentHeight;
        if (remainingHeight > lineSpacing * 2) {
          // 还有空间，尝试放一部分
          final lines = _splitParagraph(trimmed, style, maxWidth, remainingHeight);
          if (lines.$1.isNotEmpty) {
            currentPageLines.add(lines.$1);
            pages.add(currentPageLines.join('\n'));
            currentPageLines = [];
            currentHeight = 0;
            if (lines.$2.isNotEmpty) {
              // 剩余部分重新分页
              final remainingPages = _paginateText(lines.$2, maxWidth, maxHeight, style);
              pages.addAll(remainingPages);
            }
            continue;
          }
        }
        pages.add(currentPageLines.join('\n'));
        currentPageLines = [];
        currentHeight = 0;
      }

      currentPageLines.add(trimmed);
      currentHeight += tp.height;
    }

    if (currentPageLines.isNotEmpty) {
      pages.add(currentPageLines.join('\n'));
    }

    return pages.isEmpty ? [''] : pages;
  }

  /// 将一段文字按高度切分，返回 (能放下的部分, 剩余部分)
  (String, String) _splitParagraph(String text, TextStyle style, double maxWidth, double availableHeight) {
    // 逐字符二分查找切分点
    final words = text.split('');
    int lo = 0, hi = words.length;
    int best = 0;

    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final sub = words.sublist(0, mid).join();
      final tp = TextPainter(
        text: TextSpan(text: sub, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      if (tp.height <= availableHeight) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    if (best <= 0) return ('', text);
    return (words.sublist(0, best).join(), words.sublist(best).join());
  }

  // ========== 下载 ==========

  Future<void> _startDownload(List<NovelChapter> chapters) async {
    if (_isDownloading || _bookSource == null) return;

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
        source: _bookSource!,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _downloadedChapters = current;
              _totalChapters = total;
              _downloadProgress = current / total;
            });
          }
        },
        onChapterComplete: (_) {},
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
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ========== 构建 ==========

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.item));

    return Scaffold(
      backgroundColor: _settings.theme.bg,
      body: Stack(
        children: [
          // 主内容区
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleControls,
            child: _buildContent(chaptersAsync),
          ),

          // 亮度遮罩
          if (_settings.brightness >= 0)
            IgnorePointer(
              child: Opacity(
                opacity: 1.0 - _settings.brightness,
                child: Container(color: Colors.black),
              ),
            ),

          // 顶部控制栏
          SlideTransition(
            position: _topBarAnimation,
            child: _buildTopBar(chaptersAsync),
          ),

          // 底部控制栏
          SlideTransition(
            position: _bottomBarAnimation,
            child: _buildBottomBar(chaptersAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AsyncValue<ChaptersResult> chaptersAsync) {
    return chaptersAsync.when(
      data: (result) {
        if (result.chapters.isEmpty) {
          return Center(child: Text('暂无章节', style: TextStyle(color: _settings.theme.text)));
        }
        _bookSource ??= result.source;
        if (_currentChapter == null) {
          if (_savedChapterIndex != null && _savedChapterIndex! < result.chapters.length) {
            _currentChapter = result.chapters[_savedChapterIndex!];
          } else {
            _currentChapter = result.chapters.first;
          }
        }
        return _buildReader(_currentChapter!);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e', style: TextStyle(color: _settings.theme.text))),
    );
  }

  Widget _buildReader(NovelChapter chapter) {
    final contentAsync = ref.watch(chapterContentProvider(ChapterWithSource(chapter, _bookSource!)));

    return contentAsync.when(
      data: (content) {
        if (_settings.pageMode) {
          return _buildPageView(content);
        } else {
          return _buildScrollView(content, chapter);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载章节失败: $e', style: TextStyle(color: _settings.theme.text))),
    );
  }

  // 翻页模式
  Widget _buildPageView(String content) {
    if (_pages.isEmpty || _pageController == null) {
      _paginateContent(content);
    }

    if (_pages.isEmpty) {
      return const Center(child: Text(''));
    }

    return SafeArea(
      child: Column(
        children: [
          // 章节标题
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _settings.horizontalMargin,
              vertical: 8,
            ),
            child: Text(
              _currentChapter?.title ?? '',
              style: _settings.textStyle.copyWith(
                fontSize: _settings.fontSize - 2,
                color: _settings.theme.text.withOpacity(0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 页面内容
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                // 翻到最后一页时自动加载下一章
                if (index == _pages.length - 1) {
                  _autoNextChapter();
                }
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: _settings.horizontalMargin),
                  child: Text(
                    _pages[index],
                    style: _settings.textStyle,
                  ),
                );
              },
            ),
          ),
          // 页码
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_currentPage + 1}/${_pages.length}',
              style: TextStyle(
                fontSize: 12,
                color: _settings.theme.text.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 滚动模式
  Widget _buildScrollView(String content, NovelChapter chapter) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        _settings.horizontalMargin,
        MediaQuery.of(context).padding.top + 16,
        _settings.horizontalMargin,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapter.title,
            style: _settings.textStyle.copyWith(
              fontSize: _settings.fontSize + 4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(content, style: _settings.textStyle),
          const SizedBox(height: 40),
          _buildChapterNavigation(chapter),
        ],
      ),
    );
  }

  void _autoNextChapter() {
    final chaptersAsync = ref.read(chaptersProvider(widget.item));
    chaptersAsync.whenData((result) {
      final chapters = result.chapters;
      final index = chapters.indexOf(_currentChapter);
      if (index >= 0 && index < chapters.length - 1) {
        setState(() {
          _currentChapter = chapters[index + 1];
          _pages = [];
          _currentPage = 0;
        });
        _saveReadingProgress(chapters[index + 1]);
      }
    });
  }

  Widget _buildChapterNavigation(NovelChapter current) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.item));
    return chaptersAsync.when(
      data: (result) {
        final chapters = result.chapters;
        final index = chapters.indexOf(current);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (index > 0)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentChapter = chapters[index - 1];
                    _pages = [];
                  });
                  _saveReadingProgress(chapters[index - 1]);
                },
                icon: const Icon(Icons.chevron_left),
                label: const Text('上一章'),
              )
            else
              const SizedBox(),
            Text('${index + 1}/${chapters.length}',
                style: TextStyle(color: _settings.theme.text)),
            if (index < chapters.length - 1)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentChapter = chapters[index + 1];
                    _pages = [];
                  });
                  _saveReadingProgress(chapters[index + 1]);
                },
                icon: const Icon(Icons.chevron_right),
                label: const Text('下一章'),
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

  // ========== 顶部控制栏 ==========

  Widget _buildTopBar(AsyncValue<ChaptersResult> chaptersAsync) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Material(
        color: _settings.isDarkMode ? Colors.black87 : Colors.white.withOpacity(0.95),
        elevation: 2,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: _settings.isDarkMode ? Colors.white : Colors.black87),
                  onPressed: () {
                    _exitImmersive();
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    _currentChapter?.title ?? widget.item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _settings.isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 收藏按钮
                IconButton(
                  icon: Icon(
                    ref.watch(favoritesProvider).any((i) => i.id == widget.item.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: ref.watch(favoritesProvider).any((i) => i.id == widget.item.id)
                        ? Colors.red
                        : (_settings.isDarkMode ? Colors.white70 : Colors.grey),
                  ),
                  onPressed: () => ref.read(favoritesProvider.notifier).toggle(widget.item),
                ),
                // 下载按钮
                if (!_isDownloading)
                  IconButton(
                    icon: Icon(Icons.download, color: _settings.isDarkMode ? Colors.white70 : Colors.grey),
                    onPressed: () {
                      chaptersAsync.whenData((result) {
                        if (result.chapters.isNotEmpty) _startDownload(result.chapters);
                      });
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(value: _downloadProgress, strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== 底部控制栏 ==========

  Widget _buildBottomBar(AsyncValue<ChaptersResult> chaptersAsync) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Material(
        color: _settings.isDarkMode ? Colors.black87 : Colors.white.withOpacity(0.95),
        elevation: 2,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 章节进度滑块
                chaptersAsync.when(
                  data: (result) {
                    final chapters = result.chapters;
                    final currentIndex = chapters.indexOf(_currentChapter).toDouble();
                    return Row(
                      children: [
                        Text('上一章', style: TextStyle(fontSize: 12,
                            color: _settings.isDarkMode ? Colors.white54 : Colors.grey)),
                        Expanded(
                          child: Slider(
                            value: currentIndex < 0 ? 0 : currentIndex,
                            min: 0,
                            max: (chapters.length - 1).toDouble().clamp(1, double.infinity),
                            divisions: chapters.length > 1 ? chapters.length - 1 : 1,
                            onChanged: (v) {
                              final chapter = chapters[v.toInt()];
                              setState(() {
                                _currentChapter = chapter;
                                _pages = [];
                              });
                              _saveReadingProgress(chapter);
                            },
                          ),
                        ),
                        Text('下一章', style: TextStyle(fontSize: 12,
                            color: _settings.isDarkMode ? Colors.white54 : Colors.grey)),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                // 操作按钮行
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBottomButton(Icons.toc, '目录', () {
                      _showChapterDrawer(chaptersAsync);
                    }),
                    _buildBottomButton(Icons.settings, '设置', () {
                      _showSettingsSheet();
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton(IconData icon, String label, VoidCallback onTap) {
    final color = _settings.isDarkMode ? Colors.white70 : Colors.black54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  // ========== 设置弹窗 ==========

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ReaderSettingsSheet(
          settings: _settings,
          onChanged: (newSettings) {
            setState(() {
              final fontSizeChanged = newSettings.fontSize != _settings.fontSize;
              final lineHeightChanged = newSettings.lineHeight != _settings.lineHeight;
              final marginChanged = newSettings.horizontalMargin != _settings.horizontalMargin;
              _settings = newSettings;
              if (newSettings.pageMode && (fontSizeChanged || lineHeightChanged || marginChanged)) {
                _pages = []; // 触发重新分页
              }
            });
            _saveSettings();
          },
        );
      },
    );
  }

  // ========== 目录抽屉 ==========

  void _showChapterDrawer(AsyncValue<ChaptersResult> chaptersAsync) {
    chaptersAsync.whenData((result) {
      final chapters = result.chapters;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: _settings.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('目录',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _settings.isDarkMode ? Colors.white : Colors.black)),
                          Text('${chapters.length}章',
                              style: TextStyle(color: _settings.isDarkMode ? Colors.white54 : Colors.grey[400])),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
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
                                    : (_settings.isDarkMode ? Colors.white70 : null),
                                fontWeight: isCurrent ? FontWeight.bold : null,
                              ),
                            ),
                            trailing: isCurrent ? const Icon(Icons.check) : null,
                            onTap: () {
                              setState(() {
                                _currentChapter = chapter;
                                _pages = [];
                              });
                              _saveReadingProgress(chapter);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }
}
