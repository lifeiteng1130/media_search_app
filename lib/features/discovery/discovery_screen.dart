import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/rule_engine.dart';
import '../../repositories/book_source_repository.dart';
import '../../models/book_source.dart';
import '../../models/book_search_result.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final List<_ExploreGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExplore();
  }

  Future<void> _loadExplore() async {
    setState(() {
      _isLoading = true;
      _groups.clear();
    });

    final sourceRepo = BookSourceRepository(ApiClient());
    final allSources = await sourceRepo.getAll();
    final exploreSources = allSources.where((s) =>
        s.enabled && s.enabledExplore && s.exploreUrl != null && s.exploreUrl!.isNotEmpty &&
        s.ruleExplore != null).toList();

    final apiClient = ApiClient();

    for (final source in exploreSources.take(10)) {
      try {
        var url = source.exploreUrl!;
        if (!url.startsWith('http')) {
          url = url.startsWith('/')
              ? '${source.bookSourceUrl}$url'
              : '${source.bookSourceUrl}/$url';
        }

        final html = await apiClient.fetchHtml(url).timeout(const Duration(seconds: 10));
        final rule = source.ruleExplore!;
        final elements = RuleEngine.extractAll(html, rule.bookList);

        final items = <BookSearchResult>[];
        for (final element in elements.take(20)) {
          final name = RuleEngine.extractFromElement(element, rule.name);
          if (name == null || name.isEmpty) continue;

          var bookUrl = RuleEngine.extractFromElement(element, rule.bookUrl) ?? '';
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = RuleEngine.resolveUrl(source.bookSourceUrl, bookUrl);
          }
          if (bookUrl.isEmpty) continue;

          var coverUrl = rule.coverUrl.isNotEmpty
              ? RuleEngine.extractFromElement(element, rule.coverUrl) : null;
          if (coverUrl != null && coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = RuleEngine.resolveUrl(source.bookSourceUrl, coverUrl);
          }

          final author = rule.author.isNotEmpty
              ? RuleEngine.extractFromElement(element, rule.author) : null;

          items.add(BookSearchResult(
            title: name,
            author: author,
            coverUrl: coverUrl?.isNotEmpty == true ? coverUrl : null,
            detailUrl: bookUrl,
            source: source.bookSourceName,
            bookSourceUrl: source.bookSourceUrl,
          ));
        }

        if (items.isNotEmpty && mounted) {
          setState(() {
            _groups.add(_ExploreGroup(source: source, items: items));
          });
        }
      } catch (_) {
        continue;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExplore,
          ),
        ],
      ),
      body: _isLoading && _groups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore_off, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text('暂无推荐内容', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('请先启用带发现功能的书源', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadExplore,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _groups.length,
                    itemBuilder: (ctx, index) => _buildGroup(_groups[index]),
                  ),
                ),
    );
  }

  Widget _buildGroup(_ExploreGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(group.source.bookSourceName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: group.items.length,
            itemBuilder: (ctx, index) => _buildBookCard(group.items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildBookCard(BookSearchResult item) {
    return GestureDetector(
      onTap: () => context.push('/book-detail', extra: item),
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
                clipBehavior: Clip.antiAlias,
                child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.coverUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => Center(child: Icon(Icons.book, color: Colors.grey[600])),
                      )
                    : Center(child: Icon(Icons.book, color: Colors.grey[600])),
              ),
            ),
            const SizedBox(height: 4),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ExploreGroup {
  final BookSource source;
  final List<BookSearchResult> items;

  _ExploreGroup({required this.source, required this.items});
}
