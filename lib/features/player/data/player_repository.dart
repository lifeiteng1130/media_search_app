import '../../../core/network/api_client.dart';
import '../../search/data/models/media_item.dart';
import 'source_resolver.dart';

class PlayerRepository {
  final ApiClient _apiClient;
  late final SourceResolver _sourceResolver;

  PlayerRepository(this._apiClient) {
    _sourceResolver = SourceResolver(_apiClient);
  }

  /// 获取播放源列表
  Future<List<PlaySource>> getPlaySources(MediaItem item) async {
    if (item.detailUrl == null) return [];
    return _sourceResolver.resolve(item.detailUrl!);
  }
}
