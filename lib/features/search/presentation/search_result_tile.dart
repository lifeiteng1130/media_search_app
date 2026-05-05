import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/media_item.dart';
import '../data/models/media_type.dart';

class SearchResultTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const SearchResultTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildCover(),
              const SizedBox(width: 12),
              Expanded(child: _buildInfo(context)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 70,
        height: 95,
        child: item.coverUrl != null
            ? CachedNetworkImage(
                imageUrl: item.coverUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[800],
                  child: const Center(child: Icon(Icons.movie, size: 30)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[800],
                  child: const Center(child: Icon(Icons.broken_image, size: 30)),
                ),
              )
            : Container(
                color: Colors.grey[800],
                child: Center(
                  child: Icon(
                    _typeIcon(),
                    size: 30,
                    color: Colors.white54,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            _buildTag(item.mediaType.label, _typeColor()),
            if (item.year != null) _buildTag(item.year!, Colors.grey),
            if (item.rating != null) _buildTag('${item.rating!.toStringAsFixed(1)}分', Colors.amber),
            if (item.source != null) _buildTag(item.source!, Colors.blue),
          ],
        ),
        if (item.description != null) ...[
          const SizedBox(height: 6),
          Text(
            item.description!,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }

  Color _typeColor() {
    switch (item.mediaType) {
      case MediaType.movie:
        return Colors.orange;
      case MediaType.tv:
        return Colors.blue;
      case MediaType.anime:
        return Colors.purple;
      case MediaType.novel:
        return Colors.green;
    }
  }

  IconData _typeIcon() {
    switch (item.mediaType) {
      case MediaType.movie:
        return Icons.movie;
      case MediaType.tv:
        return Icons.tv;
      case MediaType.anime:
        return Icons.animation;
      case MediaType.novel:
        return Icons.book;
    }
  }
}
