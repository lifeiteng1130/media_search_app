import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/network/api_client.dart';
import '../../repositories/book_source_repository.dart';
import '../../repositories/book_repository.dart';
import '../../models/book_search_result.dart';
import '../../models/book_source.dart';
import '../../models/book_chapter.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final BookSearchResult result;

  const BookDetailScreen({super.key, required this.result});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  BookSource? _currentSource;
  List<BookChapter> _chapters = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters({BookSource? preferredSource}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _chapters = [];
    });

    final sourceRepo = BookSourceRepository(ApiClient());
    final bookRepo = BookRepository(ApiClient(), sourceRepo);
    final allSources = await sourceRepo.getAll();

    // 构建尝试顺序：优先指定源 > 原始源 > 有 ruleToc 的启用源（按权重）
    List<BookSource> sourcesToTry = [];

    if (preferredSource != null) {
      sourcesToTry.add(preferredSource);
    }

    // 原始源
    final originalSource = allSources
        .where((s) => s.bookSourceUrl == widget.result.bookSourceUrl)
        .firstOrNull;
    if (originalSource != null && !sourcesToTry.contains(originalSource)) {
      sourcesToTry.add(originalSource);
    }

    // 其他有 ruleToc 的启用源，按权重降序
    final otherSources = allSources
        .where((s) => s.enabled && s.ruleToc != null && !sourcesToTry.contains(s))
        .toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    sourcesToTry.addAll(otherSources.take(15));

    // 顺序尝试，找到第一个有章节的就停止
    for (final source in sourcesToTry) {
      try {
        final chapters = await bookRepo.getChapters(widget.result.detailUrl, source)
            .timeout(const Duration(seconds: 15));
        if (chapters.isNotEmpty && mounted) {
          setState(() {
            _currentSource = source;
            _chapters = chapters;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {
        continue;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = '未能加载章节列表，请尝试换源';
      });
    }
  }

  Future<void> _addToBookshelf() async {
    final box = await Hive.openBox('bookshelf');
    await box.put(widget.result.detailUrl, {
      'title': widget.result.title,
      'author': widget.result.author,
      'coverUrl': widget.result.coverUrl,
      'detailUrl': widget.result.detailUrl,
      'source': _currentSource?.bookSourceName ?? widget.result.source,
      'bookSourceUrl': _currentSource?.bookSourceUrl ?? widget.result.bookSourceUrl,
      'lastChapter': _chapters.isNotEmpty ? _chapters.last.title : '',
      'lastReadTime': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加入书架')),
      );
    }
  }

  void _openReader(int chapterIndex) {
    _saveReadHistory(chapterIndex);
    context.push('/reader', extra: {
      'title': widget.result.title,
      'chapters': _chapters,
      'initialIndex': chapterIndex,
      'source': _currentSource!,
      'detailUrl': widget.result.detailUrl,
    });
  }

  Future<void> _saveReadHistory(int chapterIndex) async {
    final box = await Hive.openBox('read_history');
    await box.put(widget.result.detailUrl, {
      'title': widget.result.title,
      'author': widget.result.author,
      'coverUrl': widget.result.coverUrl,
      'detailUrl': widget.result.detailUrl,
      'source': _currentSource?.bookSourceName ?? '',
      'bookSourceUrl': _currentSource?.bookSourceUrl ?? '',
      'chapterTitle': _chapters[chapterIndex].title,
      'chapterIndex': chapterIndex,
      'lastReadTime': DateTime.now().toIso8601String(),
    });
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SourcePickerSheet(
        detailUrl: widget.result.detailUrl,
        currentSource: _currentSource,
        onSelected: (source) {
          Navigator.pop(ctx);
          _loadChapters(preferredSource: source);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 100,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[800],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: widget.result.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.result.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Center(child: Icon(Icons.book, color: Colors.grey[600])),
                                )
                              : Center(child: Icon(Icons.book, size: 40, color: Colors.grey[600])),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.result.title,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (widget.result.author != null) ...[
                                const SizedBox(height: 4),
                                Text('作者: ${widget.result.author}',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                              ],
                              const SizedBox(height: 4),
                              Text('来源: ${_currentSource?.bookSourceName ?? widget.result.source}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _chapters.isNotEmpty ? () => _openReader(0) : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('开始阅读'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _addToBookshelf,
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('加书架'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _showSourcePicker,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('换源'),
                  ),
                ],
              ),
            ),
          ),
          if (widget.result.intro != null && widget.result.intro!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(widget.result.intro!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text('目录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (!_isLoading && _chapters.isNotEmpty)
                    Text('共${_chapters.length}章', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: TextStyle(color: Colors.grey[400])),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _loadChapters(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _showSourcePicker,
                      child: const Text('手动换源'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = _chapters[index];
                  return ListTile(
                    dense: true,
                    title: Text(chapter.title, style: const TextStyle(fontSize: 14)),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
                    onTap: () => _openReader(index),
                  );
                },
                childCount: _chapters.length,
              ),
            ),
        ],
      ),
    );
  }
}

/// 换源弹窗 - 自动查询每个源的章节数
class SourcePickerSheet extends StatefulWidget {
  final String detailUrl;
  final BookSource? currentSource;
  final void Function(BookSource) onSelected;

  const SourcePickerSheet({
    super.key,
    required this.detailUrl,
    this.currentSource,
    required this.onSelected,
  });

  @override
  State<SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<SourcePickerSheet> {
  String _filter = '';
  List<_SourceInfo> _sourceInfos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final sourceRepo = BookSourceRepository(ApiClient());
    final allSources = await sourceRepo.getEnabled();
    final bookRepo = BookRepository(ApiClient(), sourceRepo);

    // 先显示列表，后台逐个查询章节
    setState(() {
      _sourceInfos = allSources
          .where((s) => s.ruleToc != null)
          .map((s) => _SourceInfo(source: s, chapterCount: -1, isLoading: true))
          .toList();
      _isLoading = false;
    });

    // 并发查询每个源的章节数（限制并发数）
    for (int i = 0; i < _sourceInfos.length; i += 5) {
      final batch = _sourceInfos.sublist(i, (i + 5).clamp(0, _sourceInfos.length));
      await Future.wait(batch.map((info) async {
        try {
          final chapters = await bookRepo.getChapters(widget.detailUrl, info.source)
              .timeout(const Duration(seconds: 10));
          if (mounted) {
            setState(() {
              final idx = _sourceInfos.indexWhere((s) => s.source.bookSourceUrl == info.source.bookSourceUrl);
              if (idx >= 0) {
                _sourceInfos[idx] = _SourceInfo(
                  source: info.source,
                  chapterCount: chapters.length,
                  isLoading: false,
                );
              }
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              final idx = _sourceInfos.indexWhere((s) => s.source.bookSourceUrl == info.source.bookSourceUrl);
              if (idx >= 0) {
                _sourceInfos[idx] = _SourceInfo(
                  source: info.source,
                  chapterCount: 0,
                  isLoading: false,
                );
              }
            });
          }
        }
      }));
    }
  }

  List<_SourceInfo> get _filtered {
    var list = _sourceInfos;
    if (_filter.isNotEmpty) {
      list = list.where((s) =>
          s.source.bookSourceName.toLowerCase().contains(_filter.toLowerCase()) ||
          s.source.bookSourceGroup.toLowerCase().contains(_filter.toLowerCase())).toList();
    }
    // 有章节的排前面，按章节数降序
    list.sort((a, b) {
      if (a.isLoading && !b.isLoading) return 1;
      if (!a.isLoading && b.isLoading) return -1;
      return b.chapterCount.compareTo(a.chapterCount);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('选择书源', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('自动检测每个源的章节数', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: '搜索书源...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: filtered.length,
              itemBuilder: (ctx, index) {
                final info = filtered[index];
                final isCurrent = info.source.bookSourceUrl == widget.currentSource?.bookSourceUrl;
                return _buildSourceTile(info, isCurrent);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTile(_SourceInfo info, bool isCurrent) {
    final hasChapters = info.chapterCount > 0;

    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(info.source.bookSourceName, style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: hasChapters ? null : Colors.grey[600],
            )),
          ),
          if (isCurrent)
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 18),
        ],
      ),
      subtitle: Text(
        info.source.bookSourceGroup.isEmpty ? info.source.bookSourceUrl : info.source.bookSourceGroup,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
      trailing: _buildChapterBadge(info),
      onTap: () => widget.onSelected(info.source),
    );
  }

  Widget _buildChapterBadge(_SourceInfo info) {
    if (info.isLoading) {
      return const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (info.chapterCount <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('无章节', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('${info.chapterCount}章', style: TextStyle(fontSize: 11, color: Colors.green[400])),
    );
  }
}

class _SourceInfo {
  final BookSource source;
  final int chapterCount;
  final bool isLoading;

  _SourceInfo({required this.source, required this.chapterCount, this.isLoading = false});
}
