import 'package:dio/dio.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    ));
    dio.interceptors.add(LogInterceptor(responseBody: false));
  }

  /// 通用 GET 请求
  Future<Response> get(String url, {Map<String, dynamic>? params}) {
    return dio.get(url, queryParameters: params);
  }

  /// 通用 POST 请求
  Future<Response> post(String url, {Map<String, dynamic>? data}) {
    return dio.post(url, data: data != null ? FormData.fromMap(data) : null);
  }

  /// 获取 HTML 页面内容
  Future<String> fetchHtml(String url) async {
    final response = await dio.get(url);
    return response.data as String;
  }

  /// 下载文件
  Future<void> download(String url, String savePath, {ProgressCallback? onProgress}) async {
    await dio.download(url, savePath, onReceiveProgress: onProgress);
  }
}
