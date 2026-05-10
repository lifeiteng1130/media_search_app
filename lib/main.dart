import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';
import 'core/network/api_client.dart';
import 'features/novel/data/book_source_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('search_history');
  await Hive.openBox('favorites');
  await Hive.openBox('read_history');

  // 加载默认书源（首次启动时从 assets 导入 180+ 书源到 Hive）
  final bookSourceRepo = BookSourceRepository(ApiClient());
  await bookSourceRepo.loadDefaults();

  runApp(const ProviderScope(child: MediaSearchApp()));
}
