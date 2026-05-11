import 'package:flutter/services.dart';
import '../models/book_source.dart';

Future<List<BookSource>> loadDefaultBookSources() async {
  try {
    final jsonStr = await rootBundle.loadString('lib/features/novel/data/default_sources.json');
    return parseBookSourcesJson(jsonStr);
  } catch (e) {
    return [];
  }
}
