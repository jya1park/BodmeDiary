import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/routes.dart';

class RootShell extends StatelessWidget {
  const RootShell({required this.child, super.key});
  final Widget child;

  static const _tabs = [
    (Routes.home, Icons.home_rounded, '홈'),
    (Routes.history, Icons.bar_chart_rounded, '히스토리'),
    (Routes.photo, Icons.camera_alt_rounded, '사진'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final i = _tabs.indexWhere((t) => loc.startsWith(t.$1));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => context.go(_tabs[i].$1),
        items: [
          for (final t in _tabs)
            BottomNavigationBarItem(icon: Icon(t.$2), label: t.$3),
        ],
      ),
    );
  }
}
