import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/novel_repository.dart';
import '../../../core/network/api_client.dart';

/// 小说下载服务
class NovelDownloadService {
  static const String _downloadBoxName = 'novel_downloads';
  static const String _downloadDirName = 'downloaded_novels';

  /// 获取下载存储目录
  Future<Directory> _getDownloadDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/$_downloadDirName');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// 获取小说存储目录
  Future<Directory> _getNovelDir(String novelTitle) async {
    final downloadDir = await _getDownloadDir();
    // 清理标题中的非法字符
    final safeTitle = novelTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final novelDir = Directory('${downloadDir.path}/$safeTitle');
    if (!await novelDir.exists()) {
      await novelDir.create(recursive: true);
    }
    return novelDir;
  }

  /// 获取下载记录 Box
  Future<Box> _getDownloadBox() async {
    if (!Hive.isBoxOpen(_downloadBoxName)) {
      return await Hive.openBox(_downloadBoxName);
    }
    return Hive.box(_downloadBoxName);
  }

  /// 获取所有已下载的小说
  Future<List<DownloadedNovel>> getAllDownloaded() async {
    final box = await _getDownloadBox();
    final List<DownloadedNovel> novels = [];

    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        novels.add(DownloadedNovel.fromJson(Map<String, dynamic>.from(data)));
      }
    }

    return novels;
  }

  /// 检查小说是否已下载
  Future<bool> isDownloaded(String detailUrl) async {
    final box = await _getDownloadBox();
    return box.containsKey(detailUrl);
  }

  /// 获取已下载的小说信息
  Future<DownloadedNovel?> getDownloadedNovel(String detailUrl) async {
    final box = await _getDownloadBox();
    final data = box.get(detailUrl);
    if (data != null) {
      return DownloadedNovel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// 下载小说
  Future<DownloadedNovel> downloadNovel({
    required String title,
    required String author,
    required String coverUrl,
    required String detailUrl,
    required List<NovelChapter> chapters,
    required Function(int current, int total) onProgress,
    required Function(String chapterTitle) onChapterComplete,
  }) async {
    final novelDir = await _getNovelDir(title);
    final box = await _getDownloadBox();

    // 创建下载记录
    var downloadedNovel = DownloadedNovel(
      title: title,
      author: author,
      coverUrl: coverUrl,
      detailUrl: detailUrl,
      chapters: chapters.map((c) => DownloadedChapter(
        title: c.title,
        url: c.url,
        index: c.index,
        filePath: '${novelDir.path}/${c.index}_${_safeFileName(c.title)}.txt',
        isDownloaded: false,
      )).toList(),
      downloadTime: DateTime.now(),
    );

    // 保存初始记录
    await box.put(detailUrl, downloadedNovel.toJson());

    // 下载每个章节
    final repository = NovelRepository(ApiClient());
    int completed = 0;

    for (int i = 0; i < downloadedNovel.chapters.length; i++) {
      final chapter = downloadedNovel.chapters[i];

      try {
        // 获取章节内容
        final content = await repository.getChapterContent(chapter.url);

        // 保存到文件
        final file = File(chapter.filePath);
        await file.writeAsString(content);

        // 更新章节状态
        downloadedNovel.chapters[i] = chapter.copyWith(isDownloaded: true);
        completed++;

        onChapterComplete(chapter.title);
        onProgress(completed, downloadedNovel.chapters.length);

        // 保存进度
        await box.put(detailUrl, downloadedNovel.toJson());
      } catch (e) {
        // 单个章节下载失败不影响整体
        print('下载章节失败: ${chapter.title} - $e');
      }
    }

    // 更新下载时间
    downloadedNovel = downloadedNovel.copyWith(downloadTime: DateTime.now());
    await box.put(detailUrl, downloadedNovel.toJson());

    return downloadedNovel;
  }

  /// 读取已下载的章节内容
  Future<String> readChapterContent(DownloadedChapter chapter) async {
    final file = File(chapter.filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    throw Exception('章节文件不存在: ${chapter.title}');
  }

  /// 删除下载的小说
  Future<void> deleteDownload(String detailUrl) async {
    final box = await _getDownloadBox();
    final data = box.get(detailUrl);

    if (data != null) {
      final novel = DownloadedNovel.fromJson(Map<String, dynamic>.from(data));

      // 删除文件目录
      if (novel.chapters.isNotEmpty) {
        final novelDir = Directory(novel.chapters.first.filePath).parent;
        if (await novelDir.exists()) {
          await novelDir.delete(recursive: true);
        }
      }

      // 删除记录
      await box.delete(detailUrl);
    }
  }

  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(' ', '_');
  }
}

/// 已下载的小说
class DownloadedNovel {
  final String title;
  final String author;
  final String? coverUrl;
  final String detailUrl;
  final List<DownloadedChapter> chapters;
  final DateTime downloadTime;

  DownloadedNovel({
    required this.title,
    required this.author,
    this.coverUrl,
    required this.detailUrl,
    required this.chapters,
    required this.downloadTime,
  });

  int get downloadedCount => chapters.where((c) => c.isDownloaded).length;
  bool get isFullyDownloaded => chapters.every((c) => c.isDownloaded);

  DownloadedNovel copyWith({
    String? title,
    String? author,
    String? coverUrl,
    String? detailUrl,
    List<DownloadedChapter>? chapters,
    DateTime? downloadTime,
  }) {
    return DownloadedNovel(
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      detailUrl: detailUrl ?? this.detailUrl,
      chapters: chapters ?? this.chapters,
      downloadTime: downloadTime ?? this.downloadTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'detailUrl': detailUrl,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'downloadTime': downloadTime.toIso8601String(),
    };
  }

  factory DownloadedNovel.fromJson(Map<String, dynamic> json) {
    return DownloadedNovel(
      title: json['title'] as String,
      author: json['author'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      detailUrl: json['detailUrl'] as String,
      chapters: (json['chapters'] as List?)
          ?.map((c) => DownloadedChapter.fromJson(Map<String, dynamic>.from(c)))
          .toList() ?? [],
      downloadTime: DateTime.parse(json['downloadTime'] as String),
    );
  }
}

/// 已下载的章节
class DownloadedChapter {
  final String title;
  final String url;
  final int index;
  final String filePath;
  final bool isDownloaded;

  DownloadedChapter({
    required this.title,
    required this.url,
    required this.index,
    required this.filePath,
    required this.isDownloaded,
  });

  DownloadedChapter copyWith({
    String? title,
    String? url,
    int? index,
    String? filePath,
    bool? isDownloaded,
  }) {
    return DownloadedChapter(
      title: title ?? this.title,
      url: url ?? this.url,
      index: index ?? this.index,
      filePath: filePath ?? this.filePath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'index': index,
      'filePath': filePath,
      'isDownloaded': isDownloaded,
    };
  }

  factory DownloadedChapter.fromJson(Map<String, dynamic> json) {
    return DownloadedChapter(
      title: json['title'] as String,
      url: json['url'] as String? ?? '',
      index: json['index'] as int? ?? 0,
      filePath: json['filePath'] as String,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
    );
  }
}
