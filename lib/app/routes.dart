import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/bookshelf/bookshelf_screen.dart';
import '../features/discovery/discovery_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/detail/book_detail_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/sources/book_source_screen.dart';
import '../models/book_search_result.dart';
import '../models/book_source.dart';
import '../models/book_chapter.dart';

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
            GoRoute(path: '/', builder: (context, state) => const BookshelfScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/discovery', builder: (context, state) => const DiscoveryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/book-detail',
        builder: (context, state) {
          final result = state.extra as BookSearchResult;
          return BookDetailScreen(result: result);
        },
      ),
      GoRoute(
        path: '/reader',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return ReaderScreen(
            title: args['title'] as String,
            chapters: args['chapters'] as List<BookChapter>,
            initialIndex: args['initialIndex'] as int? ?? 0,
            source: args['source'] as BookSource,
            detailUrl: args['detailUrl'] as String,
          );
        },
      ),
      GoRoute(
        path: '/book-sources',
        builder: (context, state) => const BookSourceScreen(),
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
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: '书架'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: '发现'),
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
