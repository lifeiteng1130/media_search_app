class BookSearchResult {
  final String title;
  final String? author;
  final String? coverUrl;
  final String? intro;
  final String detailUrl;
  final String source;
  final String bookSourceUrl;

  const BookSearchResult({
    required this.title,
    this.author,
    this.coverUrl,
    this.intro,
    required this.detailUrl,
    required this.source,
    required this.bookSourceUrl,
  });
}
