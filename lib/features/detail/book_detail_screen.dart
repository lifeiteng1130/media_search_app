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

    // 确定要尝试的源列表
    List<BookSource> sourcesToTry = [];

    if (preferredSource != null) {
      sourcesToTry.add(preferredSource);
    }

    // 尝试原始源
    final allSources = await sourceRepo.getAll();
    final originalSource = allSources.where((s) => s.bookSourceUrl == widget.result.bookSourceUrl).firstOrNull;
    if (originalSource != null && !sourcesToTry.contains(originalSource)) {
      sourcesToTry.add(originalSource);
    }

    // 按权重排序的其他源
    final otherSources = allSources
        .where((s) => s.enabled && s.ruleToc != null && !sourcesToTry.contains(s))
        .toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));

    sourcesToTry.addAll(otherSources.take(10));

    // 顺序尝试
    for (final source in sourcesToTry) {
      try {
        final chapters = await bookRepo.getChapters(widget.result.detailUrl, source);
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
      'source': widget.result.source,
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
    // 保存阅读历史
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

  Future<void> _showSourcePicker() async {
    final sourceRepo = BookSourceRepository(ApiClient());
    final allSources = await sourceRepo.getEnabled();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SourcePickerSheet(
        sources: allSources,
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
          // 操作按钮
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
          // 简介
          if (widget.result.intro != null && widget.result.intro!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(widget.result.intro!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ),
          // 章节标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('目录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (!_isLoading && _chapters.isNotEmpty)
                    Text('共${_chapters.length}章', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
          ),
          // 章节列表
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
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

class _SourcePickerSheet extends StatefulWidget {
  final List<BookSource> sources;
  final BookSource? currentSource;
  final void Function(BookSource) onSelected;

  const _SourcePickerSheet({
    required this.sources,
    this.currentSource,
    required this.onSelected,
  });

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  String _filter = '';
  late List<BookSource> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.sources;
  }

  void _updateFilter(String query) {
    setState(() {
      _filter = query;
      _filtered = query.isEmpty
          ? widget.sources
          : widget.sources.where((s) =>
              s.bookSourceName.toLowerCase().contains(query.toLowerCase()) ||
              s.bookSourceGroup.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('选择书源', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: '搜索书源...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: _updateFilter,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: _filtered.length,
              itemBuilder: (ctx, index) {
                final source = _filtered[index];
                final isCurrent = source.bookSourceUrl == widget.currentSource?.bookSourceUrl;
                return ListTile(
                  title: Text(source.bookSourceName, style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  )),
                  subtitle: Text(source.bookSourceGroup, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  trailing: isCurrent
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => widget.onSelected(source),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
