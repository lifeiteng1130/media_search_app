import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../reader/reader_settings.dart' as rs;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.source),
            title: const Text('书源管理'),
            subtitle: const Text('管理小说书源'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/book-sources'),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('阅读设置'),
            subtitle: const Text('字体、行高、背景色'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReaderSettings(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('清除缓存'),
            subtitle: const Text('清除搜索历史和临时数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showClearCacheDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('文渊阁 v2.0.0'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showReaderSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _ReaderSettingsPreview(),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存数据吗？这包括搜索历史、阅读历史等。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await Hive.openBox('search_history').then((b) => b.clear());
              await Hive.openBox('read_history').then((b) => b.clear());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清除')));
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
      builder: (ctx) => AlertDialog(
        title: const Text('关于'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文渊阁', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('版本: 2.0.0'),
            SizedBox(height: 16),
            Text('一款基于 Legado 规则的小说阅读应用。'),
            SizedBox(height: 8),
            Text('功能特性:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 多书源搜索与阅读'),
            Text('• 自定义书源导入'),
            Text('• 翻页/滚动两种阅读模式'),
            Text('• 丰富的阅读设置'),
            Text('• 书架管理'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
        ],
      ),
    );
  }
}

class _ReaderSettingsPreview extends StatefulWidget {
  const _ReaderSettingsPreview();

  @override
  State<_ReaderSettingsPreview> createState() => _ReaderSettingsPreviewState();
}

class _ReaderSettingsPreviewState extends State<_ReaderSettingsPreview> {
  rs.ReaderSettings _settings = rs.ReaderSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await rs.ReaderSettings.load();
    setState(() => _settings = s);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('阅读设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSlider('字体大小', _settings.fontSize, 12, 28, (v) {
            setState(() => _settings = _settings.copyWith(fontSize: v));
            _settings.save();
          }),
          _buildSlider('行高', _settings.lineHeight, 1.2, 3.0, (v) {
            setState(() => _settings = _settings.copyWith(lineHeight: v));
            _settings.save();
          }),
          _buildSlider('左右边距', _settings.horizontalMargin, 0, 40, (v) {
            setState(() => _settings = _settings.copyWith(horizontalMargin: v));
            _settings.save();
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('背景色', style: TextStyle(fontSize: 14)),
              const Spacer(),
              ...List.generate(rs.readerThemes.length, (index) {
                final theme = rs.readerThemes[index];
                final isSelected = _settings.themeIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _settings = _settings.copyWith(themeIndex: index));
                    _settings.save();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: theme.bg,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 10).toInt(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
