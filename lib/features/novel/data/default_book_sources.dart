import 'dart:convert';
import 'package:flutter/services.dart';
import 'book_source.dart';

/// 从 assets 加载默认书源
Future<List<BookSource>> loadDefaultBookSources() async {
  try {
    final jsonStr = await rootBundle.loadString('lib/features/novel/data/default_sources.json');
    return parseBookSourcesJson(jsonStr);
  } catch (e) {
    return [];
  }
}
