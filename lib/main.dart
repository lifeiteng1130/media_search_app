import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';
import 'repositories/book_source_repository.dart';
import 'core/network/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox('bookshelf');
  await Hive.openBox('search_history');
  await Hive.openBox('read_history');
  await Hive.openBox('book_sources');

  final sourceRepo = BookSourceRepository(ApiClient());
  await sourceRepo.loadDefaults();

  runApp(const ProviderScope(child: WenYuanGeApp()));
}
