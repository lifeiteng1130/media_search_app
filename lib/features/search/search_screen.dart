import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/network/api_client.dart';
import '../../repositories/book_source_repository.dart';
import '../../repositories/book_repository.dart';
import '../../models/book_search_result.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(ApiClient(), BookSourceRepository(ApiClient()));
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<BookSearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.read(bookRepositoryProvider);
  return repo.search(query.trim());
});

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox('search_history');
    state = List<String>.from(box.get('history', defaultValue: []));
  }

  Future<void> add(String query) async {
    final list = List<String>.from(state);
    list.remove(query);
    list.insert(0, query);
    if (list.length > 20) list.removeLast();
    state = list;
    final box = await Hive.openBox('search_history');
    await box.put('history', list);
  }

  Future<void> clear() async {
    state = [];
    final box = await Hive.openBox('search_history');
    await box.put('history', []);
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  void _doSearch(String query) {
    if (query.trim().isEmpty) return;
    ref.read(searchQueryProvider.notifier).state = query.trim();
    ref.read(searchHistoryProvider.notifier).add(query.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final history = ref.watch(searchHistoryProvider);
    final currentQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入书名搜索...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: _doSearch,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _doSearch(_controller.text),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          Expanded(
            child: currentQuery.isEmpty
                ? _buildHistory(history)
                : resultsAsync.when(
                    data: (results) => _buildResults(results),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('搜索失败: $e', style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _doSearch(currentQuery),
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(List<String> history) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('搜索你喜欢的小说', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('搜索历史', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              TextButton(
                onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
                child: const Text('清空', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              return ListTile(
                dense: true,
                leading: Icon(Icons.history, color: Colors.grey[500], size: 20),
                title: Text(query),
                onTap: () {
                  _controller.text = query;
                  _doSearch(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults(List<BookSearchResult> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('未找到相关书籍', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return _buildResultCard(context, item);
      },
    );
  }

  Widget _buildResultCard(BuildContext context, BookSearchResult item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/book-detail', extra: item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey[800],
                ),
                clipBehavior: Clip.antiAlias,
                child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(child: Icon(Icons.book, color: Colors.grey[600])),
                      )
                    : Center(child: Icon(Icons.book, color: Colors.grey[600])),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (item.author != null && item.author!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('作者: ${item.author}', style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text('来源: ${item.source}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
