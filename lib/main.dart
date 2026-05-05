import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('search_history');
  await Hive.openBox('favorites');
  await Hive.openBox('read_history');
  runApp(const ProviderScope(child: MediaSearchApp()));
}
