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
  String _content = '';
  bool _isLoading = true;
  String? _error;
  bool _showControls = false;
  ReaderSettings _settings = ReaderSettings();
  PageController? _pageController;
  bool _settingsReady = false;

  // 分页数据
  List<String> _pages = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialIndex;
    _pageController = PageController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settings = await ReaderSettings.load();
    _settingsReady = true;
    if (mounted) {
      setState(() {});
      _loadContent();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _content = '';
      _pages = [];
    });

    try {
      final bookRepo = BookRepository(ApiClient(), BookSourceRepository(ApiClient()));
      final content = await bookRepo.getChapterContent(
        widget.chapters[_currentChapterIndex].url,
        widget.source,
      );

      if (!mounted) return;

      setState(() {
        _content = content;
        _isLoading = false;
      });

      // 延迟一帧确保 layout 完成后再分页
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _paginate();
      });

      _saveProgress();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  void _paginate() {
    if (_content.isEmpty) return;

    final size = MediaQuery.of(context).size;
    final textW = size.width - _settings.horizontalMargin * 2;
    final textH = size.height - _settings.verticalMargin * 2 - 80;

    if (textW < 50 || textH < 50) {
      // 屏幕尺寸不够，直接用滚动模式
      setState(() => _pages = [_content]);
      return;
    }

    final pages = <String>[];
    final tp = TextPainter(textDirection: TextDirection.ltr);

    int offset = 0;
    while (offset < _content.length) {
      tp.text = TextSpan(
        text: _content.substring(offset),
        style: _settings.textStyle,
      );
      tp.layout(maxWidth: textW);

      if (tp.height <= textH) {
        pages.add(_content.substring(offset));
        break;
      }

      final pos = tp.getPositionForOffset(Offset(textW, textH));
      var end = pos.offset;
      if (end <= 0) end = 1;

      // 尝试在换行处断页
      final absEnd = offset + end;
      if (absEnd < _content.length) {
        final nl = _content.indexOf('\n', absEnd);
        if (nl != -1 && nl - absEnd < 30) {
          end = nl - offset + 1;
        }
      }

      pages.add(_content.substring(offset, offset + end));
      offset += end;
    }

    setState(() {
      _pages = pages;
      _currentPage = 0;
    });
    if (_pageController?.hasClients == true) {
      _pageController!.jumpToPage(0);
    }
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
      _content = '';
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

  void _applySettings(ReaderSettings newSettings) {
    setState(() => _settings = newSettings);
    newSettings.save();
    // 重新分页
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _paginate();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: _settings.theme.bg,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 主内容
            _buildBody(),
            // 顶部栏
            if (_showControls) _buildTopBar(),
            // 底部栏（含设置）
            if (_showControls) _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _settings.theme.text.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('正在加载...', style: TextStyle(color: _settings.theme.text.withOpacity(0.5))),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: _settings.theme.text.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: _settings.theme.text)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadContent, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_content.isEmpty) {
      return Center(
        child: Text('章节内容为空', style: TextStyle(color: _settings.theme.text.withOpacity(0.5))),
      );
    }

    // 优先翻页模式
    if (_settings.pageMode && _pages.isNotEmpty) {
      return PageView.builder(
        controller: _pageController,
        itemCount: _pages.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (ctx, i) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _settings.horizontalMargin,
            vertical: _settings.verticalMargin,
          ),
          child: Text(_pages[i], style: _settings.textStyle),
        ),
      );
    }

    // 滚动模式（或分页失败时的 fallback）
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: _settings.horizontalMargin,
        vertical: _settings.verticalMargin,
      ),
      child: Text(_content, style: _settings.textStyle),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
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
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
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
                  Text('${_currentChapterIndex + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _currentChapterIndex.toDouble(),
                      min: 0,
                      max: (widget.chapters.length - 1).toDouble(),
                      onChanged: (v) => _goToChapter(v.toInt()),
                    ),
                  ),
                  Text('${widget.chapters.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _barBtn(Icons.skip_previous, '上一章',
                    _currentChapterIndex > 0 ? () => _goToChapter(_currentChapterIndex - 1) : null),
                _barBtn(Icons.skip_next, '下一章',
                    _currentChapterIndex < widget.chapters.length - 1 ? () => _goToChapter(_currentChapterIndex + 1) : null),
                _barBtn(Icons.list, '目录', _showChapterList),
                _barBtn(Icons.settings, '设置', _showSettingsPanel),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _barBtn(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onTap != null ? Colors.white : Colors.grey[600], size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
                color: onTap != null ? Colors.white : Colors.grey[600], fontSize: 11)),
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
        initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
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
                itemBuilder: (ctx, i) {
                  final isCur = i == _currentChapterIndex;
                  return ListTile(
                    dense: true,
                    title: Text(widget.chapters[i].title, style: TextStyle(
                      fontSize: 14,
                      color: isCur ? Theme.of(context).colorScheme.primary : null,
                      fontWeight: isCur ? FontWeight.bold : null,
                    )),
                    trailing: isCur
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 20)
                        : null,
                    onTap: () { Navigator.pop(ctx); _goToChapter(i); },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _InlineSettingsSheet(
        settings: _settings,
        onChanged: _applySettings,
      ),
    );
  }
}

/// 内嵌设置面板 - 直接在阅读页底部弹出
class _InlineSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const _InlineSettingsSheet({required this.settings, required this.onChanged});

  @override
  State<_InlineSettingsSheet> createState() => _InlineSettingsSheetState();
}

class _InlineSettingsSheetState extends State<_InlineSettingsSheet> {
  late ReaderSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(ReaderSettings Function(ReaderSettings) fn) {
    setState(() => _s = fn(_s));
    widget.onChanged(_s);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽条
            Center(
              child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            ),
            // 阅读模式
            Row(
              children: [
                const Text('阅读模式', style: TextStyle(fontSize: 14)),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('翻页'), icon: Icon(Icons.chrome_reader_mode)),
                    ButtonSegment(value: false, label: Text('滚动'), icon: Icon(Icons.swap_vert)),
                  ],
                  selected: {_s.pageMode},
                  onSelectionChanged: (v) => _update((s) => s.copyWith(pageMode: v.first)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 字体大小
            _slider('字体', _s.fontSize, 12, 28, (v) => _update((s) => s.copyWith(fontSize: v))),
            // 行高
            _slider('行高', _s.lineHeight, 1.0, 3.0, (v) => _update((s) => s.copyWith(lineHeight: v))),
            // 边距
            _slider('边距', _s.horizontalMargin, 0, 40, (v) => _update((s) => s.copyWith(horizontalMargin: v))),
            const SizedBox(height: 16),
            // 背景色
            const Text('背景色', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(readerThemes.length, (i) {
                final t = readerThemes[i];
                final sel = _s.themeIndex == i;
                return GestureDetector(
                  onTap: () => _update((s) => s.copyWith(themeIndex: i)),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: t.bg,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                          : Border.all(color: Colors.grey[700]!, width: 1),
                    ),
                    child: sel
                        ? Icon(Icons.check, color: t.text, size: 18)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 45, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value, min: min, max: max,
            divisions: ((max - min) * 10).toInt(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 36, child: Text(value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
      ],
    );
  }
}
