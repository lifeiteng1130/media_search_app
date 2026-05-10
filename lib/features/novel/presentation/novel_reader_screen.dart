import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../search/data/models/media_item.dart';
import '../../favorites/presentation/favorites_provider.dart';
import '../data/novel_repository.dart';
import '../data/book_source.dart';
import '../data/book_source_repository.dart';
import '../data/reader_settings.dart';
import '../data/novel_download_service.dart';
import '../../../core/network/api_client.dart';
import 'reader_settings_sheet.dart';

// ========== Providers ==========

final bookSourceRepositoryProvider = Provider<BookSourceRepository>((ref) {
  return BookSourceRepository(ApiClient());
});

final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  return NovelRepository(ApiClient(), ref.read(bookSourceRepositoryProvider));
});

// ========== 详情页状态 ==========

class NovelDetailState {
  final BookSource? source;
  final List<NovelChapter> chapters;
  final bool isLoading;
  final String? error;

  const NovelDetailState({
    this.source,
    this.chapters = const [],
    this.isLoading = false,
    this.error,
  });

  NovelDetailState copyWith({
    BookSource? source,
    List<NovelChapter>? chapters,
    bool? isLoading,
    String? error,
  }) {
    return NovelDetailState(
      source: source ?? this.source,
      chapters: chapters ?? this.chapters,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NovelDetailNotifier extends StateNotifier<NovelDetailState> {
  final NovelRepository _repo;
  final BookSourceRepository _sourceRepo;
  final MediaItem _item;

  NovelDetailNotifier(this._repo, this._sourceRepo, this._item)
      : super(const NovelDetailState()) {
    loadChapters();
  }

  String? get _detailUrl => _item.detailUrl;

  /// 加载章节（顺序尝试，找到即停）
  Future<void> loadChapters({BookSource? preferredSource}) async {
    final detailUrl = _detailUrl;
    if (detailUrl == null) {
      state = const NovelDetailState(error: '无效的书籍链接');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    final triedUrls = <String>{};
    final sourcesToTry = <BookSource>[];

    // 1. 指定的书源
    if (preferredSource != null) {
      sourcesToTry.add(preferredSource);
      triedUrls.add(preferredSource.bookSourceUrl);
    }

    // 2. item.bookSourceUrl 匹配的源
    if (_item.bookSourceUrl != null && _item.bookSourceUrl!.isNotEmpty) {
      if (!triedUrls.contains(_item.bookSourceUrl)) {
        final found = await _sourceRepo.findByUrl(_item.bookSourceUrl!);
        if (found != null) {
          sourcesToTry.add(found);
          triedUrls.add(found.bookSourceUrl);
        }
      }
    }

    // 3. detailUrl 前缀匹配的源
    final urlMatch = await _sourceRepo.findByUrl(detailUrl);
    if (urlMatch != null && !triedUrls.contains(urlMatch.bookSourceUrl)) {
      sourcesToTry.add(urlMatch);
      triedUrls.add(urlMatch.bookSourceUrl);
    }

    // 逐个尝试
    for (final source in sourcesToTry) {
      final result = await _trySource(detailUrl, source);
      if (result != null) return;
    }

    // 4. 按权重降序取前 10 个源，逐个尝试
    final allSources = await _sourceRepo.getEnabled();
    final candidates = allSources
        .where((s) => !triedUrls.contains(s.bookSourceUrl))
        .toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));

    for (final source in candidates.take(10)) {
      final result = await _trySource(detailUrl, source);
      if (result != null) return;
    }

    // 全部失败
    if (mounted) {
      state = const NovelDetailState(
        isLoading: false,
        error: '未找到可用书源，请手动换源',
      );
    }
  }

  /// 尝试单个书源，成功返回 ChaptersResult，失败返回 null
  Future<ChaptersResult?> _trySource(String detailUrl, BookSource source) async {
    try {
      final chapters = await _repo
          .getChapters(detailUrl, source)
          .timeout(const Duration(seconds: 15));
      if (chapters.isNotEmpty && mounted) {
        state = NovelDetailState(
          source: source,
          chapters: chapters,
          isLoading: false,
        );
        return ChaptersResult(chapters, source);
      }
    } catch (_) {}
    return null;
  }

  /// 换源
  Future<void> changeSource(BookSource source) async {
    state = NovelDetailState(isLoading: true, error: null);
    await loadChapters(preferredSource: source);
  }
}

class ChaptersResult {
  final List<NovelChapter> chapters;
  final BookSource? source;
  const ChaptersResult(this.chapters, this.source);
}

final novelDetailProvider = StateNotifierProvider.family<
    NovelDetailNotifier, NovelDetailState, MediaItem>((ref, item) {
  return NovelDetailNotifier(
    ref.read(novelRepositoryProvider),
    ref.read(bookSourceRepositoryProvider),
    item,
  );
});

// ========== 章节内容 ==========

class ChapterWithSource {
  final NovelChapter chapter;
  final BookSource source;
  const ChapterWithSource(this.chapter, this.source);
}

final chapterContentProvider =
    FutureProvider.family<String, ChapterWithSource>((ref, cws) async {
  final repo = ref.read(novelRepositoryProvider);
  return repo.getChapterContent(cws.chapter.url, cws.source);
});

// ========== 详情页（入口） ==========

class NovelDetailScreen extends ConsumerStatefulWidget {
  final MediaItem item;
  const NovelDetailScreen({super.key, required this.item});

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen> {
  @override
  void initState() {
    super.initState();
    _saveToHistory();
  }

  Future<void> _saveToHistory() async {
    try {
      final box = await Hive.openBox('read_history');
      final existing = box.get(widget.item.detailUrl);
      await box.put(widget.item.detailUrl, {
        'title': widget.item.title,
        'chapterTitle': existing != null
            ? (Map<String, dynamic>.from(existing)['chapterTitle'] ?? '')
            : '',
        'chapterIndex': existing != null
            ? (Map<String, dynamic>.from(existing)['chapterIndex'] ?? 0)
            : 0,
        'chapterUrl': existing != null
            ? (Map<String, dynamic>.from(existing)['chapterUrl'] ?? '')
            : '',
        'coverUrl': widget.item.coverUrl ?? '',
        'lastReadTime': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void _showSourcePicker() async {
    final sourceRepo = ref.read(bookSourceRepositoryProvider);
    final sources = await sourceRepo.getEnabled();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _SourcePickerSheet(
          sources: sources,
          onSourceSelected: (source) {
            Navigator.pop(ctx);
            ref.read(novelDetailProvider(widget.item).notifier).changeSource(source);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(novelDetailProvider(widget.item));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部封面栏
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blueGrey[900]!, Colors.blueGrey[700]!],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 封面图
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 100,
                            height: 140,
                            child: widget.item.coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: widget.item.coverUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.book,
                                          color: Colors.white54, size: 40),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.book,
                                          color: Colors.white54, size: 40),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.book,
                                        color: Colors.white54, size: 40),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 书名和来源
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              if (widget.item.description != null &&
                                  widget.item.description!.isNotEmpty)
                                Text(
                                  widget.item.description!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.7)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              if (widget.item.source != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '来源: ${widget.item.source}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.8)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              Consumer(
                builder: (context, ref, _) {
                  final isFav = ref
                      .watch(favoritesProvider)
                      .any((i) => i.id == widget.item.id);
                  return IconButton(
                    icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.white),
                    onPressed: () => ref
                        .read(favoritesProvider.notifier)
                        .toggle(widget.item),
                  );
                },
              ),
            ],
          ),

          // 书源信息 + 换源按钮
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.source, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      detailState.source != null
                          ? '书源: ${detailState.source!.bookSourceName}'
                          : (detailState.isLoading
                              ? '正在匹配书源...'
                              : '未匹配到书源'),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('换源', style: TextStyle(fontSize: 13)),
                    onPressed: _showSourcePicker,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 章节标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text('目录',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (detailState.chapters.isNotEmpty)
                    Text(
                      '${detailState.chapters.length}章',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
          ),

          // 章节列表 / 加载中 / 错误
          if (detailState.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载章节...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (detailState.error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(detailState.error!,
                        style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('换源'),
                      onPressed: _showSourcePicker,
                    ),
                  ],
                ),
              ),
            )
          else if (detailState.chapters.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('暂无章节', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    Text('点击上方「换源」尝试其他书源',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = detailState.chapters[index];
                  return ListTile(
                    dense: true,
                    title: Text(chapter.title,
                        style: const TextStyle(fontSize: 14)),
                    trailing:
                        const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      if (detailState.source != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NovelReaderScreen(
                              item: widget.item,
                              chapters: detailState.chapters,
                              initialChapter: chapter,
                              source: detailState.source!,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
                childCount: detailState.chapters.length,
              ),
            ),
        ],
      ),
    );
  }
}

// ========== 书源选择弹窗 ==========

class _SourcePickerSheet extends StatefulWidget {
  final List<BookSource> sources;
  final ValueChanged<BookSource> onSourceSelected;

  const _SourcePickerSheet({
    required this.sources,
    required this.onSourceSelected,
  });

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var filtered = widget.sources;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((s) =>
              s.bookSourceName.toLowerCase().contains(q) ||
              s.bookSourceUrl.toLowerCase().contains(q) ||
              s.bookSourceGroup.toLowerCase().contains(q))
          .toList();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('选择书源',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface)),
                    ),
                    Text('${filtered.length}个',
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5))),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // 搜索栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索书源名称或网址...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant
                        .withOpacity(0.5),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const Divider(height: 1),
              // 书源列表
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('没有匹配的书源',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5))))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final source = filtered[index];
                          return ListTile(
                            title: Text(source.bookSourceName,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(source.bookSourceUrl,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.4)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: source.bookSourceGroup.isNotEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      source.bookSourceGroup,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              theme.colorScheme.primary),
                                    ),
                                  )
                                : null,
                            onTap: () => widget.onSourceSelected(source),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== 阅读页面 ==========

class NovelReaderScreen extends ConsumerStatefulWidget {
  final MediaItem item;
  final List<NovelChapter> chapters;
  final NovelChapter initialChapter;
  final BookSource source;

  const NovelReaderScreen({
    super.key,
    required this.item,
    required this.chapters,
    required this.initialChapter,
    required this.source,
  });

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen>
    with SingleTickerProviderStateMixin {
  late NovelChapter _currentChapter;
  late BookSource _bookSource;
  ReaderSettings _settings = ReaderSettings();

  // 翻页
  PageController? _pageController;
  List<String> _pages = [];
  int _currentPage = 0;

  // 控制栏
  bool _showControls = false;
  late AnimationController _controlsAnimController;
  late Animation<Offset> _topBarAnimation;
  late Animation<Offset> _bottomBarAnimation;

  // 下载
  final _downloadService = NovelDownloadService();
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter;
    _bookSource = widget.source;

    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _topBarAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _controlsAnimController, curve: Curves.easeOut));
    _bottomBarAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _controlsAnimController, curve: Curves.easeOut));

    _loadSettings();
    _saveReadingProgress();
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
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _saveReadingProgress() async {
    try {
      final box = await Hive.openBox('read_history');
      await box.put(widget.item.detailUrl, {
        'title': widget.item.title,
        'chapterTitle': _currentChapter.title,
        'chapterIndex': _currentChapter.index,
        'chapterUrl': _currentChapter.url,
        'coverUrl': widget.item.coverUrl ?? '',
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

  void _goToChapter(NovelChapter chapter) {
    _pageController?.dispose();
    _pageController = null;
    setState(() {
      _currentChapter = chapter;
      _pages = [];
      _currentPage = 0;
    });
    _saveReadingProgress();
  }

  // ========== 分页引擎 ==========

  void _paginateContent(String content) {
    if (!_settings.pageMode) return;

    final mq = MediaQuery.of(context);
    final maxWidth = mq.size.width - _settings.horizontalMargin * 2;
    final maxHeight = mq.size.height - mq.padding.top - mq.padding.bottom - 60;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final pages = <String>[];
    final paragraphs = content.split('\n');
    var currentPageBuffer = StringBuffer();
    var currentHeight = 0.0;
    final lineH = _settings.fontSize * _settings.lineHeight;

    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) {
        currentHeight += lineH * 0.5;
        if (currentHeight >= maxHeight) {
          if (currentPageBuffer.isNotEmpty) {
            pages.add(currentPageBuffer.toString());
            currentPageBuffer = StringBuffer();
          }
          currentHeight = 0;
        }
        continue;
      }

      textPainter.text = TextSpan(text: trimmed, style: _settings.textStyle);
      textPainter.layout(maxWidth: maxWidth);

      if (currentHeight + textPainter.height > maxHeight &&
          currentPageBuffer.isNotEmpty) {
        pages.add(currentPageBuffer.toString());
        currentPageBuffer = StringBuffer();
        currentHeight = 0;
      }

      currentPageBuffer.writeln(trimmed);
      currentHeight += textPainter.height;
    }

    if (currentPageBuffer.isNotEmpty) {
      pages.add(currentPageBuffer.toString());
    }

    _pages = pages.isEmpty ? [''] : pages;
    _pageController = PageController();
    _currentPage = 0;
  }

  // ========== 下载 ==========

  Future<void> _startDownload() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      await _downloadService.downloadNovel(
        title: widget.item.title,
        author: widget.item.description ?? '',
        coverUrl: widget.item.coverUrl ?? '',
        detailUrl: widget.item.detailUrl ?? '',
        chapters: widget.chapters,
        source: _bookSource,
        onProgress: (current, total) {
          if (mounted) setState(() => _downloadProgress = current / total);
        },
        onChapterComplete: (_) {},
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('下载完成')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('下载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _settings.theme.bg,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleControls,
            child: _buildContent(),
          ),
          if (_settings.brightness >= 0)
            IgnorePointer(
              child: Opacity(
                opacity: 1.0 - _settings.brightness,
                child: Container(color: Colors.black),
              ),
            ),
          if (_showControls)
            SlideTransition(
                position: _topBarAnimation, child: _buildTopBar()),
          if (_showControls)
            SlideTransition(
                position: _bottomBarAnimation, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final contentAsync = ref.watch(
      chapterContentProvider(ChapterWithSource(_currentChapter, _bookSource)),
    );

    return contentAsync.when(
      data: (content) {
        if (_settings.pageMode) {
          return _buildPageView(content);
        } else {
          return _buildScrollView(content);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('章节内容加载失败',
                style: TextStyle(color: _settings.theme.text)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(chapterContentProvider(
                  ChapterWithSource(_currentChapter, _bookSource))),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView(String content) {
    if (_pages.isEmpty || _pageController == null) {
      _paginateContent(content);
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: _settings.horizontalMargin, vertical: 8),
            child: Text(
              _currentChapter.title,
              style: _settings.textStyle.copyWith(
                fontSize: _settings.fontSize - 2,
                color: _settings.theme.text.withOpacity(0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                if (index == _pages.length - 1) _autoNextChapter();
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: _settings.horizontalMargin),
                  child: Text(_pages[index], style: _settings.textStyle),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_currentPage + 1}/${_pages.length}',
              style: TextStyle(
                  fontSize: 12,
                  color: _settings.theme.text.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollView(String content) {
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
            _currentChapter.title,
            style: _settings.textStyle.copyWith(
              fontSize: _settings.fontSize + 4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(content, style: _settings.textStyle),
          const SizedBox(height: 40),
          _buildChapterNavigation(),
        ],
      ),
    );
  }

  void _autoNextChapter() {
    final index = widget.chapters.indexOf(_currentChapter);
    if (index >= 0 && index < widget.chapters.length - 1) {
      _goToChapter(widget.chapters[index + 1]);
    }
  }

  Widget _buildChapterNavigation() {
    final index = widget.chapters.indexOf(_currentChapter);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (index > 0)
          ElevatedButton.icon(
            onPressed: () => _goToChapter(widget.chapters[index - 1]),
            icon: const Icon(Icons.chevron_left),
            label: const Text('上一章'),
          )
        else
          const SizedBox(),
        Text('${index + 1}/${widget.chapters.length}',
            style: TextStyle(color: _settings.theme.text)),
        if (index < widget.chapters.length - 1)
          ElevatedButton.icon(
            onPressed: () => _goToChapter(widget.chapters[index + 1]),
            icon: const Icon(Icons.chevron_right),
            label: const Text('下一章'),
          )
        else
          const SizedBox(),
      ],
    );
  }

  // ========== 顶部栏 ==========

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: _settings.isDarkMode
            ? Colors.black87
            : Colors.white.withOpacity(0.95),
        elevation: 2,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: _settings.isDarkMode
                          ? Colors.white
                          : Colors.black87),
                  onPressed: () {
                    _exitImmersive();
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    _currentChapter.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _settings.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final isFav = ref
                        .watch(favoritesProvider)
                        .any((i) => i.id == widget.item.id);
                    return IconButton(
                      icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.grey),
                      onPressed: () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(widget.item),
                    );
                  },
                ),
                if (!_isDownloading)
                  IconButton(
                    icon: Icon(Icons.download,
                        color: _settings.isDarkMode
                            ? Colors.white70
                            : Colors.grey),
                    onPressed: _startDownload,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          value: _downloadProgress, strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== 底部栏 ==========

  Widget _buildBottomBar() {
    final index = widget.chapters.indexOf(_currentChapter);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        color: _settings.isDarkMode
            ? Colors.black87
            : Colors.white.withOpacity(0.95),
        elevation: 2,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('上一章', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: index
                            .toDouble()
                            .clamp(0, (widget.chapters.length - 1).toDouble()),
                        min: 0,
                        max: (widget.chapters.length - 1)
                            .toDouble()
                            .clamp(1, double.infinity),
                        divisions: widget.chapters.length > 1
                            ? widget.chapters.length - 1
                            : 1,
                        onChanged: (v) =>
                            _goToChapter(widget.chapters[v.toInt()]),
                      ),
                    ),
                    const Text('下一章', style: TextStyle(fontSize: 12)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _bottomBtn(Icons.toc, '目录', _showChapterDrawer),
                    _bottomBtn(Icons.settings, '设置', _showSettingsSheet),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBtn(IconData icon, String label, VoidCallback onTap) {
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
              final changed =
                  newSettings.fontSize != _settings.fontSize ||
                      newSettings.lineHeight != _settings.lineHeight ||
                      newSettings.horizontalMargin !=
                          _settings.horizontalMargin;
              _settings = newSettings;
              if (newSettings.pageMode && changed) {
                _pageController?.dispose();
                _pageController = null;
                _pages = [];
              }
            });
            _settings.save();
          },
        );
      },
    );
  }

  // ========== 目录 ==========

  void _showChapterDrawer() {
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
            final initialIndex =
                widget.chapters.indexOf(_currentChapter);
            if (initialIndex > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                scrollController.animateTo(
                  initialIndex * 56.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              });
            }
            return Container(
              decoration: BoxDecoration(
                color: _settings.isDarkMode
                    ? const Color(0xFF1A1A1A)
                    : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
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
                                color: _settings.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        Text('${widget.chapters.length}章',
                            style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: widget.chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = widget.chapters[index];
                        final isCurrent = chapter == _currentChapter;
                        return ListTile(
                          title: Text(
                            chapter.title,
                            style: TextStyle(
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : (_settings.isDarkMode
                                      ? Colors.white70
                                      : null),
                              fontWeight:
                                  isCurrent ? FontWeight.bold : null,
                            ),
                          ),
                          trailing:
                              isCurrent ? const Icon(Icons.check) : null,
                          onTap: () {
                            _goToChapter(chapter);
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
  }
}
