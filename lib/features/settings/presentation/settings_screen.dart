import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/data_sources.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // 数据源配置
          _buildSection(
            context,
            title: '影视资源站',
            icon: Icons.movie,
            sources: DataSources.videoSources.map((s) => s.name).toList(),
          ),
          _buildSection(
            context,
            title: '动漫资源站',
            icon: Icons.animation,
            sources: DataSources.animeSources.map((s) => s.name).toList(),
          ),

          const Divider(),

          // 书源管理
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('书源管理'),
            subtitle: const Text('管理小说书源（180+ 内置源）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/book-sources');
            },
          ),

          // 下载管理
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('下载管理'),
            subtitle: const Text('查看和管理已下载的小说'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/downloads');
            },
          ),

          // 缓存管理
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('清除缓存'),
            subtitle: const Text('清除搜索历史和临时数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showClearCacheDialog(context),
          ),

          const Divider(),

          // 关于
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('资源搜索 v1.0.0'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> sources,
  }) {
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: sources.map((name) {
        return ListTile(
          title: Text(name),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
          dense: true,
        );
      }).toList(),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存数据吗？这包括搜索历史、阅读历史等。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              // 清除搜索历史
              final searchBox = await Hive.openBox('search_history');
              await searchBox.clear();

              // 清除阅读历史
              final readBox = await Hive.openBox('read_history');
              await readBox.clear();

              // 清除播放历史
              final playBox = await Hive.openBox('play_history');
              await playBox.clear();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清除')),
                );
              }
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('资源搜索', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('版本: 1.0.0'),
            SizedBox(height: 16),
            Text('一款聚合搜索影视、动漫、小说资源的应用。'),
            SizedBox(height: 8),
            Text('功能特性:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 影视搜索与在线观看'),
            Text('• 动漫搜索与在线观看'),
            Text('• 小说搜索、在线阅读与下载'),
            Text('• 收藏功能'),
            Text('• 阅读/观看历史'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
