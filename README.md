# 资源搜索 App

一款聚合搜索影视、动漫、小说资源的 Flutter 应用。

## 功能特性

- 影视搜索：聚合多个资源站，支持电影、电视剧搜索
- 动漫搜索：整合动漫资源站，在线观看
- 小说搜索：笔趣阁等小说站聚合，支持阅读
- TMDB 元数据：自动获取封面、评分、简介
- 收藏功能：本地收藏喜欢的资源
- 搜索历史：记录搜索关键词

## 快速开始

### 1. 安装 Flutter

```bash
# Windows
# 下载 Flutter SDK: https://docs.flutter.dev/get-started/install/windows

# 配置环境变量
export PATH="$PATH:[flutter路径]/bin"

# 验证安装
flutter doctor
```

### 2. 运行项目

```bash
cd media_search_app
flutter pub get
flutter run
```

### 3. 配置 TMDB API Key（可选，用于获取影视元数据）

1. 注册 [TMDB](https://www.themoviedb.org/) 账号
2. 在 Settings → API 中申请 API Key
3. 编辑 `lib/core/constants/api_endpoints.dart`，替换 `YOUR_TMDB_API_KEY`

## 数据源配置

### 影视资源站

在 `lib/core/config/data_sources.dart` 中配置：

```dart
static const videoSources = [
  VideoSource(
    name: '站点名称',
    baseUrl: 'https://example.com',
    searchPath: '/search?keyword={query}',
    resultSelector: '.result-item',  // CSS 选择器
    titleSelector: '.title',
    linkSelector: 'a[href]',
    coverSelector: 'img',
    descSelector: '.description',
  ),
  // 添加更多站点...
];
```

### 小说资源站

```dart
static const novelSources = [
  NovelSource(
    name: '笔趣阁',
    baseUrl: 'https://www.biquges.com',
    searchPath: '/search.php?q={query}',
    resultSelector: '.result-item',
    titleSelector: '.title a',
    linkSelector: 'a[href]',
    coverSelector: 'img',
    authorSelector: '.author',
    chapterSelector: '.chapter-list a',
    contentSelector: '.chapter-content',
  ),
];
```

### 动漫资源站

```dart
static const animeSources = [
  AnimeSource(
    name: 'AGE动漫',
    baseUrl: 'https://www.agemys.org',
    searchPath: '/search?query={query}',
    resultSelector: '.module-item',
    titleSelector: '.title',
    linkSelector: 'a[href]',
    coverSelector: 'img',
    descSelector: '.description',
  ),
];
```

## 添加新数据源

1. 打开 `lib/core/config/data_sources.dart`
2. 根据站点类型添加到对应列表
3. 配置 CSS 选择器（需要先分析目标站点的 HTML 结构）

### 如何获取 CSS 选择器

1. 在浏览器打开目标站点
2. 右键点击搜索结果 → 检查元素
3. 查看 HTML 结构，找到合适的 CSS 选择器

## 项目结构

```
lib/
├── main.dart                    # 入口
├── app/
│   ├── app.dart                # MaterialApp 配置
│   └── routes.dart             # 路由 + 底部导航
├── core/
│   ├── config/
│   │   └── data_sources.dart   # 数据源配置 ⭐
│   ├── network/
│   │   └── api_client.dart     # Dio 网络请求
│   ├── constants/
│   │   └── api_endpoints.dart  # API 地址
│   └── utils/
│       └── html_parser.dart    # HTML 解析
├── features/
│   ├── search/                 # 搜索功能
│   ├── player/                 # 视频播放
│   ├── novel/                  # 小说阅读
│   ├── favorites/              # 收藏
│   └── settings/               # 设置
└── shared/
    ├── widgets/                # 通用组件
    └── theme/                  # 主题
```

## 注意事项

1. 部分资源站可能有反爬机制，需要处理：
   - User-Agent 设置
   - Cookie 处理
   - Referer 头设置

2. 视频播放可能遇到：
   - m3u8 格式需要 HLS 支持
   - 部分视频需要特定 Referer 才能播放
   - 跨域问题可能需要代理

3. 建议先用 1-2 个稳定的资源源测试，确认可行后再扩展

## 常见问题

**Q: 搜索没有结果？**
A: 检查网络连接，确认资源站可访问。部分站点可能需要科学上网。

**Q: 视频无法播放？**
A: 可能是播放源需要特定的 Referer 或 Cookie，检查 SourceResolver 的配置。

**Q: 如何添加新的资源站？**
A: 参考上方"添加新数据源"部分，配置 CSS 选择器即可。
