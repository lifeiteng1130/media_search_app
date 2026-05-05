import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/novel_download_service.dart';

/// 下载管理界面
class NovelDownloadScreen extends ConsumerStatefulWidget {
  const NovelDownloadScreen({super.key});

  @override
  ConsumerState<NovelDownloadScreen> createState() => _NovelDownloadScreenState();
}

class _NovelDownloadScreenState extends ConsumerState<NovelDownloadScreen> {
  final _downloadService = NovelDownloadService();
  List<DownloadedNovel> _downloadedNovels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedNovels();
  }

  Future<void> _loadDownloadedNovels() async {
    setState(() => _isLoading = true);
    try {
      final novels = await _downloadService.getAllDownloaded();
      setState(() {
        _downloadedNovels = novels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteDownload(DownloadedNovel novel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除《${novel.title}》的下载吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _downloadService.deleteDownload(novel.detailUrl);
        await _loadDownloadedNovels();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloadedNovels.isEmpty
              ? _buildEmptyState()
              : _buildDownloadList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_done_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无下载内容',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在小说详情页点击下载按钮开始下载',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadList() {
    return RefreshIndicator(
      onRefresh: _loadDownloadedNovels,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _downloadedNovels.length,
        itemBuilder: (context, index) {
          final novel = _downloadedNovels[index];
          return _buildNovelCard(novel);
        },
      ),
    );
  }

  Widget _buildNovelCard(DownloadedNovel novel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // 导航到阅读界面
          Navigator.pushNamed(
            context,
            '/novel-reader-offline',
            arguments: novel,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 80,
                  child: novel.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: novel.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.book, color: Colors.white54),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.book, color: Colors.white54),
                          ),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.book, color: Colors.white54),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.author,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          novel.isFullyDownloaded
                              ? Icons.check_circle
                              : Icons.downloading,
                          size: 16,
                          color: novel.isFullyDownloaded
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${novel.downloadedCount}/${novel.chapters.length} 章',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(novel.downloadTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteDownload(novel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
