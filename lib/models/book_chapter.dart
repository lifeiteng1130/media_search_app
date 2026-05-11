class BookChapter {
  final String title;
  final String url;
  final int index;

  const BookChapter({required this.title, required this.url, required this.index});

  Map<String, dynamic> toJson() => {'title': title, 'url': url, 'index': index};

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      title: json['title'] as String,
      url: json['url'] as String,
      index: json['index'] as int,
    );
  }
}
