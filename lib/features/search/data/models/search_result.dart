import 'media_item.dart';

class SearchResult {
  final List<MediaItem> items;
  final int totalCount;
  final int page;
  final bool hasMore;

  const SearchResult({
    required this.items,
    this.totalCount = 0,
    this.page = 1,
    this.hasMore = false,
  });
}
