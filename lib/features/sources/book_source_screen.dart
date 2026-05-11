import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../repositories/book_source_repository.dart';
import '../../models/book_source.dart';

final bookSourceRepoProvider = Provider<BookSourceRepository>((ref) {
  return BookSourceRepository(ApiClient());
});

final allSourcesProvider = FutureProvider<List<BookSource>>((ref) async {
  final repo = ref.read(bookSourceRepoProvider);
  return repo.getAll();
});

class BookSourceScreen extends ConsumerStatefulWidget {
  const BookSourceScreen({super.key});

  @override
  ConsumerState<BookSourceScreen> createState() => _BookSourceScreenState();
}

class _BookSourceScreenState extends ConsumerState<BookSourceScreen> {
  String _filter = '';
  bool _showEnabledOnly = false;

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(allSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _handleMenu(v),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'import_clipboard', child: Text('从剪贴板导入')),
              PopupMenuItem(value: 'import_url', child: Text('从URL导入')),
              PopupMenuItem(value: 'reload', child: Text('重新加载默认源')),
              PopupMenuItem(value: 'enable_all', child: Text('全部启用')),
              PopupMenuItem(value: 'disable_all', child: Text('全部禁用')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '搜索书源...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('仅启用'),
                  selected: _showEnabledOnly,
                  onSelected: (v) => setState(() => _showEnabledOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: sourcesAsync.when(
              data: (sources) {
                var filtered = sources;
                if (_filter.isNotEmpty) {
                  filtered = filtered.where((s) =>
                      s.bookSourceName.toLowerCase().contains(_filter.toLowerCase()) ||
                      s.bookSourceUrl.toLowerCase().contains(_filter.toLowerCase())).toList();
                }
                if (_showEnabledOnly) {
                  filtered = filtered.where((s) => s.enabled).toList();
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text('共 ${filtered.length} 个书源',
                              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final source = filtered[index];
                          return _buildSourceTile(source);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTile(BookSource source) {
    return ListTile(
      title: Text(source.bookSourceName, style: const TextStyle(fontSize: 14)),
      subtitle: Text(source.bookSourceUrl, style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Switch(
        value: source.enabled,
        onChanged: (v) async {
          final repo = ref.read(bookSourceRepoProvider);
          await repo.toggleEnabled(source.bookSourceUrl);
          ref.invalidate(allSourcesProvider);
        },
      ),
      onTap: () => _showSourceDetail(source),
    );
  }

  void _showSourceDetail(BookSource source) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: Colors.grey[600], borderRadius: BorderRadius.circular(2),
              ))),
              const SizedBox(height: 16),
              Text(source.bookSourceName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _detailRow('地址', source.bookSourceUrl),
              _detailRow('分组', source.bookSourceGroup.isEmpty ? '无' : source.bookSourceGroup),
              _detailRow('权重', source.weight.toString()),
              _detailRow('搜索URL', source.searchUrl),
              _detailRow('状态', source.enabled ? '启用' : '禁用'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(source.enabled ? Icons.toggle_off : Icons.toggle_on),
                    label: Text(source.enabled ? '禁用' : '启用'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final repo = ref.read(bookSourceRepoProvider);
                      await repo.toggleEnabled(source.bookSourceUrl);
                      ref.invalidate(allSourcesProvider);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('删除', style: TextStyle(color: Colors.red)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final repo = ref.read(bookSourceRepoProvider);
                      await repo.delete(source.bookSourceUrl);
                      ref.invalidate(allSourcesProvider);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _handleMenu(String action) async {
    final repo = ref.read(bookSourceRepoProvider);

    switch (action) {
      case 'import_clipboard':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null) {
          final count = await repo.importFromJson(data!.text!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(count > 0 ? '导入成功: $count 个书源' : '未找到有效书源')),
            );
            ref.invalidate(allSourcesProvider);
          }
        }
        break;
      case 'import_url':
        final urlController = TextEditingController();
        final url = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('从URL导入'),
            content: TextField(
              controller: urlController,
              decoration: const InputDecoration(hintText: '输入书源URL'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(ctx, urlController.text), child: const Text('导入')),
            ],
          ),
        );
        if (url != null && url.isNotEmpty) {
          final count = await repo.importFromUrl(url);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(count > 0 ? '导入成功: $count 个书源' : '导入失败')),
            );
            ref.invalidate(allSourcesProvider);
          }
        }
        break;
      case 'reload':
        await repo.reloadDefaults();
        ref.invalidate(allSourcesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已重新加载默认书源')));
        }
        break;
      case 'enable_all':
        await repo.setAllEnabled(true);
        ref.invalidate(allSourcesProvider);
        break;
      case 'disable_all':
        await repo.setAllEnabled(false);
        ref.invalidate(allSourcesProvider);
        break;
    }
  }
}
