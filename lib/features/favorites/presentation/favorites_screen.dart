import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/favorites_repository.dart';
import '../../search/data/models/media_item.dart';
import '../../search/data/models/media_type.dart';
import '../../search/presentation/search_result_tile.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<MediaItem>>((ref) {
  return FavoritesNotifier(ref.read(favoritesRepositoryProvider));
});

class FavoritesNotifier extends StateNotifier<List<MediaItem>> {
  final FavoritesRepository _repo;
  FavoritesNotifier(this._repo) : super(_repo.getAll());

  void toggle(MediaItem item) {
    _repo.toggle(item);
    state = _repo.getAll();
  }

  void remove(String id) {
    _repo.remove(id);
    state = _repo.getAll();
  }

  bool isFavorite(String id) => _repo.isFavorite(id);
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('还没有收藏', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('搜索并收藏你喜欢的资源', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final item = favorites[index];
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    ref.read(favoritesProvider.notifier).remove(item.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已取消收藏 ${item.title}')),
                    );
                  },
                  child: SearchResultTile(
                    item: item,
                    onTap: () {
                      if (item.mediaType == MediaType.novel) {
                        context.push('/novel-reader', extra: item);
                      } else {
                        context.push('/player', extra: item);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
