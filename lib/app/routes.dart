import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/novel/presentation/novel_reader_screen.dart';
import '../features/novel/presentation/novel_download_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/search/data/models/media_item.dart';
import '../features/novel/data/novel_download_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (ctx, state) => const SearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/favorites', builder: (ctx, state) => const FavoritesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (ctx, state) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (ctx, state) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final item = state.extra as MediaItem;
          return VideoPlayerScreen(item: item);
        },
      ),
      GoRoute(
        path: '/novel-reader',
        builder: (context, state) {
          final item = state.extra as MediaItem;
          return NovelReaderScreen(item: item);
        },
      ),
      GoRoute(
        path: '/novel-reader-offline',
        builder: (context, state) {
          final novel = state.extra as DownloadedNovel;
          return NovelReaderScreen(
            item: MediaItem(
              id: novel.detailUrl,
              title: novel.title,
              coverUrl: novel.coverUrl,
              description: novel.author,
              mediaType: MediaType.novel,
              detailUrl: novel.detailUrl,
            ),
          );
        },
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const NovelDownloadScreen(),
      ),
    ],
  );
});

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.favorite), label: '收藏'),
          NavigationDestination(icon: Icon(Icons.history), label: '历史'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
