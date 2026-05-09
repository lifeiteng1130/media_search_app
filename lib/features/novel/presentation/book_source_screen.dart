import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/book_source.dart';
import '../data/book_source_repository.dart';
import '../../../core/network/api_client.dart';

final bookSourceRepoProvider = Provider<BookSourceRepository>((ref) {
  return BookSourceRepository(ApiClient());
});

final bookSourcesProvider = FutureProvider<List<BookSource>>((ref) async {
  final repo = ref.read(bookSourceRepoProvider);
  return repo.getAll();
});

class BookSourceScreen extends ConsumerStatefulWidget {
  const BookSourceScreen({super.key});

  @override
  ConsumerState<BookSourceScreen> createState() => _BookSourceScreenState();
}

class _BookSourceScreenState extends ConsumerState<BookSourceScreen> {
  String _searchQuery = '';
  bool _showOnlyEnabled = false;

  void _refresh() {
    ref.invalidate(bookSourcesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(bookSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        actions: [
          IconButton(
            icon: Icon(_showOnlyEnabled ? Icons.filter_list : Icons.filter_list_off),
            tooltip: _showOnlyEnabled ? '显示全部' : '仅显示启用',
            onPressed: () => setState(() => _showOnlyEnabled = !_showOnlyEnabled),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'enable_all', child: Text('全部启用')),
              const PopupMenuItem(value: 'disable_all', child: Text('全部禁用')),
              const PopupMenuItem(value: 'import_clipboard', child: Text('从剪贴板导入')),
              const PopupMenuItem(value: 'reload_defaults', child: Text('重载默认书源')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索书源...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // 书源列表
          Expanded(
            child: sourcesAsync.when(
              data: (sources) {
                var filtered = sources;
                if (_showOnlyEnabled) {
                  filtered = filtered.where((s) => s.enabled).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered.where((s) =>
                    s.bookSourceName.toLowerCase().contains(q) ||
                    s.bookSourceUrl.toLowerCase().contains(q) ||
                    s.bookSourceGroup.toLowerCase().contains(q)
                  ).toList();
                }
                if (filtered.isEmpty) {
                  return const Center(child: Text('没有匹配的书源'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildSourceTile(filtered[index]),
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
      title: Text(
        source.bookSourceName,
        style: const TextStyle(fontSize: 15),
      ),
      subtitle: Text(
        source.bookSourceUrl,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: Switch(
        value: source.enabled,
        onChanged: (_) => _toggleSource(source),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _handleSourceAction(action, source),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'info', child: Text('详情')),
          const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
      onTap: () => _showSourceInfo(source),
    );
  }

  Future<void> _toggleSource(BookSource source) async {
    final repo = ref.read(bookSourceRepoProvider);
    await repo.toggleEnabled(source.bookSourceUrl);
    _refresh();
  }

  void _handleMenuAction(String action) async {
    final repo = ref.read(bookSourceRepoProvider);
    switch (action) {
      case 'enable_all':
        await repo.setAllEnabled(true);
        _refresh();
        break;
      case 'disable_all':
        await repo.setAllEnabled(false);
        _refresh();
        break;
      case 'import_clipboard':
        _importFromClipboard();
        break;
      case 'reload_defaults':
        await repo.reloadDefaults();
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('默认书源已重载')),
          );
        }
        break;
    }
  }

  void _handleSourceAction(String action, BookSource source) async {
    final repo = ref.read(bookSourceRepoProvider);
    switch (action) {
      case 'info':
        _showSourceInfo(source);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除书源「${source.bookSourceName}」吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await repo.delete(source.bookSourceUrl);
          _refresh();
        }
        break;
    }
  }

  void _showSourceInfo(BookSource source) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: Text(source.bookSourceName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              _infoRow('网址', source.bookSourceUrl),
              _infoRow('分组', source.bookSourceGroup.isEmpty ? '无' : source.bookSourceGroup),
              _infoRow('类型', source.bookSourceType == 0 ? '文本' : '音频'),
              _infoRow('权重', '${source.weight}'),
              _infoRow('搜索方式', source.isPostSearch ? 'POST' : 'GET'),
              _infoRow('搜索URL', source.searchUrl),
              if (source.ruleSearch != null) ...[
                const Divider(),
                const Text('搜索规则', style: TextStyle(fontWeight: FontWeight.bold)),
                _infoRow('书列表', source.ruleSearch!.bookList),
                _infoRow('书名', source.ruleSearch!.name),
                _infoRow('书URL', source.ruleSearch!.bookUrl),
              ],
              if (source.ruleToc != null) ...[
                const Divider(),
                const Text('目录规则', style: TextStyle(fontWeight: FontWeight.bold)),
                _infoRow('章节列表', source.ruleToc!.chapterList),
                _infoRow('章节名', source.ruleToc!.chapterName),
                _infoRow('章节URL', source.ruleToc!.chapterUrl),
              ],
              if (source.ruleContent != null) ...[
                const Divider(),
                const Text('内容规则', style: TextStyle(fontWeight: FontWeight.bold)),
                _infoRow('正文', source.ruleContent!.content),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey[500]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _importFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null || data!.text!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('剪贴板为空')),
          );
        }
        return;
      }

      final repo = ref.read(bookSourceRepoProvider);
      final count = await repo.importFromJson(data.text!);
      _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(count > 0 ? '成功导入 $count 个书源' : '没有新的书源被导入')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }
}
