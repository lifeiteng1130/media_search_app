import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/network/api_client.dart';
import '../../repositories/book_source_repository.dart';
import '../../repositories/book_repository.dart';
import '../../models/book_source.dart';
import '../../models/book_chapter.dart';
import 'reader_settings.dart';
import 'reader_settings_sheet.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String title;
  final List<BookChapter> chapters;
  final int initialIndex;
  final BookSource source;
  final String detailUrl;

  const ReaderScreen({
    super.key,
    required this.title,
    required this.chapters,
    required this.initialIndex,
    required this.source,
    required this.detailUrl,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late int _currentChapterIndex;
  List<String> _pages = [];
  int _currentPageIndex = 0;
  String _content = '';
  bool _isLoading = true;
  String? _error;
  bool _showControls = false;
  late ReaderSettings _settings;
  late PageController _pageController;
  late ScrollController _scrollController;
  bool _isVerticalScrollMode = false;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialIndex;
    _pageController = PageController();
    _scrollController = ScrollController();
    _initSettings();
    _loadContent();
  }

  Future<void> _initSettings() async {
    _settings = await ReaderSettings.load();
    setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _pages = [];
    });

    try {
      final bookRepo = BookRepository(ApiClient(), BookSourceRepository(ApiClient()));
      final content = await bookRepo.getChapterContent(
        widget.chapters[_currentChapterIndex].url,
        widget.source,
      );

      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
        _paginateContent();
        _saveProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  void _paginateContent() {
    if (_content.isEmpty) return;

    final pages = <String>[];
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final textWidth = screenWidth - _settings.horizontalMargin * 2;
    final textHeight = screenHeight - _settings.verticalMargin * 2 - 100;

    final textSpan = TextSpan(text: _content, style: _settings.textStyle);
    textPainter.text = textSpan;
    textPainter.layout(maxWidth: textWidth);

    int startOffset = 0;
    while (startOffset < _content.length) {
      textPainter.text = TextSpan(
        text: _content.substring(startOffset),
        style: _settings.textStyle,
      );
      textPainter.layout(maxWidth: textWidth);

      if (textPainter.size.height <= textHeight) {
        pages.add(_content.substring(startOffset));
        break;
      }

      final endPosition = textPainter.getPositionForOffset(
        Offset(textWidth, textHeight),
      );
      var endOffset = endPosition.offset;

      // 找到最近的换行或标点
      if (endOffset < _content.length - startOffset) {
        final searchStart = startOffset + endOffset;
        final newlineIndex = _content.indexOf('\n', searchStart);
        if (newlineIndex != -1 && newlineIndex - searchStart < 50) {
          endOffset = newlineIndex - startOffset + 1;
        }
      }

      pages.add(_content.substring(startOffset, startOffset + endOffset));
      startOffset += endOffset;
    }

    setState(() {
      _pages = pages;
      _currentPageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  Future<void> _saveProgress() async {
    final box = await Hive.openBox('read_history');
    await box.put(widget.detailUrl, {
      'title': widget.title,
      'source': widget.source.bookSourceName,
      'bookSourceUrl': widget.source.bookSourceUrl,
      'chapterTitle': widget.chapters[_currentChapterIndex].title,
      'chapterIndex': _currentChapterIndex,
      'lastReadTime': DateTime.now().toIso8601String(),
    });
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    setState(() {
      _currentChapterIndex = index;
      _pages = [];
    });
    _loadContent();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ReaderSettingsSheet(
        settings: _settings,
        onChanged: (newSettings) {
          setState(() => _settings = newSettings);
          newSettings.save();
          _paginateContent();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _settings.theme.bg;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 内容区域
          GestureDetector(
            onTap: _toggleControls,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: TextStyle(color: _settings.theme.text)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadContent,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _settings.pageMode
                        ? _buildPageView()
                        : _buildScrollView(),
          ),
          // 顶部控制栏
          if (_showControls) _buildTopBar(),
          // 底部控制栏
          if (_showControls) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    if (_pages.isEmpty) return const SizedBox();

    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) => setState(() => _currentPageIndex = index),
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _settings.horizontalMargin,
            vertical: _settings.verticalMargin,
          ),
          child: Text(_pages[index], style: _settings.textStyle),
        );
      },
    );
  }

  Widget _buildScrollView() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: _settings.horizontalMargin,
        vertical: _settings.verticalMargin,
      ),
      child: Text(_content, style: _settings.textStyle),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black87,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.chapters[_currentChapterIndex].title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalChapters = widget.chapters.length;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black87,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 章节滑块
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${_currentChapterIndex + 1}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _currentChapterIndex.toDouble(),
                      min: 0,
                      max: (totalChapters - 1).toDouble(),
                      onChanged: (v) => _goToChapter(v.toInt()),
                    ),
                  ),
                  Text('$totalChapters', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
            // 操作按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: _currentChapterIndex > 0
                        ? () => _goToChapter(_currentChapterIndex - 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: _currentChapterIndex < totalChapters - 1
                        ? () => _goToChapter(_currentChapterIndex + 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.list, color: Colors.white),
                    onPressed: _showChapterList,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: _showSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('目录 (${widget.chapters.length}章)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: widget.chapters.length,
                itemBuilder: (ctx, index) {
                  final isCurrent = index == _currentChapterIndex;
                  return ListTile(
                    dense: true,
                    title: Text(
                      widget.chapters[index].title,
                      style: TextStyle(
                        fontSize: 14,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: isCurrent ? FontWeight.bold : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 20)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _goToChapter(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
