import 'package:flutter/material.dart';
import '../data/reader_settings.dart';

/// 阅读设置底部弹窗
class ReaderSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const ReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late ReaderSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(ReaderSettings newSettings) {
    setState(() => _settings = newSettings);
    widget.onChanged(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: _settings.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 阅读模式切换
            _buildSectionTitle('阅读模式'),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildModeChip('翻页', _settings.pageMode, () => _update(_settings.copyWith(pageMode: true))),
                const SizedBox(width: 12),
                _buildModeChip('滚动', !_settings.pageMode, () => _update(_settings.copyWith(pageMode: false))),
              ],
            ),
            const SizedBox(height: 20),

            // 字体大小
            _buildSectionTitle('字体大小  ${_settings.fontSize.toInt()}'),
            Slider(
              value: _settings.fontSize,
              min: 12, max: 28, divisions: 16,
              onChanged: (v) => _update(_settings.copyWith(fontSize: v)),
            ),

            // 行距
            _buildSectionTitle('行距  ${_settings.lineHeight.toStringAsFixed(1)}'),
            Slider(
              value: _settings.lineHeight,
              min: 1.2, max: 2.5, divisions: 13,
              onChanged: (v) => _update(_settings.copyWith(lineHeight: v)),
            ),

            // 左右边距
            _buildSectionTitle('边距  ${_settings.horizontalMargin.toInt()}'),
            Slider(
              value: _settings.horizontalMargin,
              min: 8, max: 40, divisions: 16,
              onChanged: (v) => _update(_settings.copyWith(horizontalMargin: v)),
            ),

            // 亮度
            _buildSectionTitle('亮度  ${_settings.brightness < 0 ? "跟随系统" : "${(_settings.brightness * 100).toInt()}%"}'),
            Slider(
              value: _settings.brightness < 0 ? 1.0 : _settings.brightness,
              min: 0.2, max: 1.0, divisions: 8,
              onChanged: (v) => _update(_settings.copyWith(brightness: v)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _update(_settings.copyWith(brightness: -1)),
                  child: Text('跟随系统', style: TextStyle(
                    color: _settings.brightness < 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  )),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 夜间模式
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('夜间模式'),
                Switch(
                  value: _settings.isDarkMode,
                  onChanged: (v) {
                    final newTheme = v ? 6 : 0; // 深色主题或默认主题
                    _update(_settings.copyWith(
                      isDarkMode: v,
                      themeIndex: newTheme,
                    ));
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 主题色选择
            _buildSectionTitle('主题'),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: readerThemes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final t = readerThemes[index];
                  final selected = _settings.themeIndex == index;
                  return GestureDetector(
                    onTap: () => _update(_settings.copyWith(themeIndex: index)),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: t.bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.blue : Colors.grey[300]!,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: selected
                          ? Icon(Icons.check, color: t.text, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _settings.isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _buildModeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : (_settings.isDarkMode ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (_settings.isDarkMode ? Colors.white70 : Colors.black54),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
