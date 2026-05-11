import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/book_search_result.dart';

final bookshelfProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final box = await Hive.openBox('bookshelf');
  final List<Map<String, dynamic>> books = [];
  for (final key in box.keys) {
    final data = box.get(key);
    if (data != null) {
      books.add(Map<String, dynamic>.from(data));
    }
  }
  books.sort((a, b) {
    final aTime = a['lastReadTime'] as String? ?? '';
    final bTime = b['lastReadTime'] as String? ?? '';
    return bTime.compareTo(aTime);
  });
  return books;
});

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('文渊阁'),
        centerTitle: true,
      ),
      body: booksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildGrid(context, ref, books);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('书架空空如也', style: TextStyle(fontSize: 18, color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('去搜索或发现中添加书籍吧', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.search),
            label: const Text('去搜索'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> books) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(bookshelfProvider),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return _buildBookCard(context, ref, book);
        },
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, WidgetRef ref, Map<String, dynamic> book) {
    final title = book['title'] as String? ?? '';
    final coverUrl = book['coverUrl'] as String?;
    final lastChapter = book['lastChapter'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        final result = BookSearchResult(
          title: title,
          author: book['author'] as String?,
          coverUrl: coverUrl,
          detailUrl: book['detailUrl'] as String,
          source: book['source'] as String? ?? '',
          bookSourceUrl: book['bookSourceUrl'] as String? ?? '',
        );
        context.push('/book-detail', extra: result);
      },
      onLongPress: () => _showBookMenu(context, ref, book),
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
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Center(child: Icon(Icons.book, color: Colors.grey[600])),
                      errorWidget: (_, __, ___) => Center(child: Icon(Icons.book, color: Colors.grey[600])),
                    )
                  : Center(child: Icon(Icons.book, size: 40, color: Colors.grey[600])),
            ),
          ),
          const SizedBox(height: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          if (lastChapter.isNotEmpty)
            Text(lastChapter, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showBookMenu(BuildContext context, WidgetRef ref, Map<String, dynamic> book) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('从书架移除'),
              onTap: () async {
                Navigator.pop(ctx);
                final box = await Hive.openBox('bookshelf');
                await box.delete(book['detailUrl']);
                ref.invalidate(bookshelfProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
