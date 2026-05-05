enum MediaType {
  movie('电影'),
  tv('电视剧'),
  anime('动漫'),
  novel('小说');

  final String label;
  const MediaType.label(this.label);

  static MediaType fromString(String value) {
    return MediaType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MediaType.movie,
    );
  }
}
