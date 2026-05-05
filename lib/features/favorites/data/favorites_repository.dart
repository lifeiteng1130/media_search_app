import 'package:hive/hive.dart';
import '../../search/data/models/media_item.dart';

class FavoritesRepository {
  static const _boxName = 'favorites';
  static const _key = 'items';

  Box get _box => Hive.box(_boxName);

  List<MediaItem> getAll() {
    final data = _box.get(_key, defaultValue: <Map<String, dynamic>>[]) as List;
    return data.map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> add(MediaItem item) async {
    final items = getAll();
    if (items.any((i) => i.id == item.id)) return;
    items.insert(0, item);
    await _box.put(_key, items.map((e) => e.toJson()).toList());
  }

  Future<void> remove(String id) async {
    final items = getAll();
    items.removeWhere((i) => i.id == id);
    await _box.put(_key, items.map((e) => e.toJson()).toList());
  }

  bool isFavorite(String id) {
    return getAll().any((i) => i.id == id);
  }

  Future<void> toggle(MediaItem item) async {
    if (isFavorite(item.id)) {
      await remove(item.id);
    } else {
      await add(item);
    }
  }
}
