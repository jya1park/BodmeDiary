import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RootShell extends StatelessWidget {
  const RootShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (Icons.home_rounded, '홈'),
    (Icons.bar_chart_rounded, '히스토리'),
    (Icons.camera_alt_rounded, '사진'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        items: [
          for (final t in _tabs)
            BottomNavigationBarItem(icon: Icon(t.$1), label: t.$2),
        ],
      ),
    );
  }
}
