import 'media_type.dart';

class MediaItem {
  final String id;
  final String title;
  final String? coverUrl;
  final String? description;
  final MediaType mediaType;
  final double? rating;
  final String? year;
  final String? source;
  final String? detailUrl;
  final List<Episode>? episodes;
  final String? bookSourceUrl; // 小说书源 URL（用于规则化解析）

  const MediaItem({
    required this.id,
    required this.title,
    this.coverUrl,
    this.description,
    required this.mediaType,
    this.rating,
    this.year,
    this.source,
    this.detailUrl,
    this.episodes,
    this.bookSourceUrl,
  });

  MediaItem copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? description,
    MediaType? mediaType,
    double? rating,
    String? year,
    String? source,
    String? detailUrl,
    List<Episode>? episodes,
    String? bookSourceUrl,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      mediaType: mediaType ?? this.mediaType,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      source: source ?? this.source,
      detailUrl: detailUrl ?? this.detailUrl,
      episodes: episodes ?? this.episodes,
      bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'coverUrl': coverUrl,
    'description': description,
    'mediaType': mediaType.name,
    'rating': rating,
    'year': year,
    'source': source,
    'detailUrl': detailUrl,
    'bookSourceUrl': bookSourceUrl,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: json['id'] as String,
    title: json['title'] as String,
    coverUrl: json['coverUrl'] as String?,
    description: json['description'] as String?,
    mediaType: MediaType.fromString(json['mediaType'] as String),
    rating: (json['rating'] as num?)?.toDouble(),
    year: json['year'] as String?,
    source: json['source'] as String?,
    detailUrl: json['detailUrl'] as String?,
    bookSourceUrl: json['bookSourceUrl'] as String?,
  );
}

class Episode {
  final String title;
  final String url;
  final int index;

  const Episode({required this.title, required this.url, required this.index});
}
