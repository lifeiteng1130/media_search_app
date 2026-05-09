import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 阅读主题
class ReaderTheme {
  final Color bg;
  final Color text;
  const ReaderTheme({required this.bg, required this.text});
}

/// 预定义阅读主题
const readerThemes = [
  ReaderTheme(bg: Color(0xFFF5F0E8), text: Color(0xFF333333)), // 米白
  ReaderTheme(bg: Color(0xFFCCE8CF), text: Color(0xFF333333)), // 护眼绿
  ReaderTheme(bg: Color(0xFFFAE8C8), text: Color(0xFF333333)), // 暖黄
  ReaderTheme(bg: Color(0xFFE8D4C8), text: Color(0xFF333333)), // 浅棕
  ReaderTheme(bg: Color(0xFFD4E4F7), text: Color(0xFF333333)), // 淡蓝
  ReaderTheme(bg: Color(0xFFF0D4E8), text: Color(0xFF333333)), // 浅粉
  ReaderTheme(bg: Color(0xFF1A1A1A), text: Color(0xFF999999)), // 深色
  ReaderTheme(bg: Color(0xFF0D0D0D), text: Color(0xFF888888)), // 纯黑
];

/// 阅读设置 - Hive 持久化
class ReaderSettings {
  static const String _boxName = 'reader_settings';
  static const String _key = 'settings';

  double fontSize;
  double lineHeight;
  double horizontalMargin;
  double verticalMargin;
  int themeIndex;
  bool isDarkMode;
  bool pageMode;
  double brightness; // -1 = 跟随系统, 0.0~1.0

  ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.8,
    this.horizontalMargin = 20,
    this.verticalMargin = 20,
    this.themeIndex = 0,
    this.isDarkMode = false,
    this.pageMode = true,
    this.brightness = -1,
  });

  ReaderTheme get theme => readerThemes[themeIndex.clamp(0, readerThemes.length - 1)];

  TextStyle get textStyle => TextStyle(
    fontSize: fontSize,
    height: lineHeight,
    color: theme.text,
    letterSpacing: 0.5,
  );

  /// 从 Hive 加载
  static Future<ReaderSettings> load() async {
    try {
      final box = await Hive.openBox(_boxName);
      final data = box.get(_key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        return ReaderSettings(
          fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18,
          lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.8,
          horizontalMargin: (map['horizontalMargin'] as num?)?.toDouble() ?? 20,
          verticalMargin: (map['verticalMargin'] as num?)?.toDouble() ?? 20,
          themeIndex: map['themeIndex'] as int? ?? 0,
          isDarkMode: map['isDarkMode'] as bool? ?? false,
          pageMode: map['pageMode'] as bool? ?? true,
          brightness: (map['brightness'] as num?)?.toDouble() ?? -1,
        );
      }
    } catch (_) {}
    return ReaderSettings();
  }

  /// 保存到 Hive
  Future<void> save() async {
    final box = await Hive.openBox(_boxName);
    await box.put(_key, {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'horizontalMargin': horizontalMargin,
      'verticalMargin': verticalMargin,
      'themeIndex': themeIndex,
      'isDarkMode': isDarkMode,
      'pageMode': pageMode,
      'brightness': brightness,
    });
  }

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalMargin,
    double? verticalMargin,
    int? themeIndex,
    bool? isDarkMode,
    bool? pageMode,
    double? brightness,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      verticalMargin: verticalMargin ?? this.verticalMargin,
      themeIndex: themeIndex ?? this.themeIndex,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      pageMode: pageMode ?? this.pageMode,
      brightness: brightness ?? this.brightness,
    );
  }
}
