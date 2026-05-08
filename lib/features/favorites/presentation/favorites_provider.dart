import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../search/data/models/media_item.dart';
import '../data/favorites_repository.dart';

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
