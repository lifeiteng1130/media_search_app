import 'package:flutter/material.dart';
import 'reader_settings.dart';

class ReaderSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const ReaderSettingsSheet({super.key, required this.settings, required this.onChanged});

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

  void _update(ReaderSettings Function(ReaderSettings) updater) {
    setState(() => _settings = updater(_settings));
    widget.onChanged(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 阅读模式
          Row(
            children: [
              const Text('翻页模式', style: TextStyle(fontSize: 14)),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('翻页'), icon: Icon(Icons.chrome_reader_mode)),
                  ButtonSegment(value: false, label: Text('滚动'), icon: Icon(Icons.swap_vert)),
                ],
                selected: {_settings.pageMode},
                onSelectionChanged: (v) => _update((s) => s.copyWith(pageMode: v.first)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 字体大小
          _buildSlider('字体大小', _settings.fontSize, 12, 28,
              (v) => _update((s) => s.copyWith(fontSize: v))),
          // 行高
          _buildSlider('行高', _settings.lineHeight, 1.2, 3.0,
              (v) => _update((s) => s.copyWith(lineHeight: v))),
          // 边距
          _buildSlider('左右边距', _settings.horizontalMargin, 0, 40,
              (v) => _update((s) => s.copyWith(horizontalMargin: v))),
          const SizedBox(height: 16),
          // 主题色
          Row(
            children: [
              const Text('背景色', style: TextStyle(fontSize: 14)),
              const Spacer(),
              ...List.generate(readerThemes.length, (index) {
                final theme = readerThemes[index];
                final isSelected = _settings.themeIndex == index;
                return GestureDetector(
                  onTap: () => _update((s) => s.copyWith(themeIndex: index)),
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
        SizedBox(
          width: 40,
          child: Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
