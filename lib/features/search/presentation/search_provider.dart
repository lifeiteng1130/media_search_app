import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/network/api_client.dart';
import '../data/models/media_item.dart';
import '../data/models/media_type.dart';
import '../data/models/search_result.dart';
import '../data/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ApiClient());
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchTypeProvider = StateProvider<MediaType?>((ref) => null);

final searchFutureProvider = FutureProvider<SearchResult>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final type = ref.watch(searchTypeProvider);
  if (query.isEmpty) return const SearchResult(items: []);

  final repo = ref.read(searchRepositoryProvider);
  final result = await repo.search(query, type: type);

  // 保存搜索历史
  _saveSearchHistory(query);

  return result;
});

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('search_history');
    state = (box.get('history', defaultValue: <String>[]) as List).cast<String>();
  }

  void add(String query) {
    state = [query, ...state.where((q) => q != query)].take(20).toList();
    Hive.box('search_history').put('history', state);
  }

  void remove(String query) {
    state = state.where((q) => q != query).toList();
    Hive.box('search_history').put('history', state);
  }

  void clear() {
    state = [];
    Hive.box('search_history').put('history', <String>[]);
  }
}

void _saveSearchHistory(String query) {
  // 由 SearchHistoryNotifier 处理
}
