import 'package:flutter/material.dart';

import 'main_tab_route.dart';

class MainTabSwipeRegion extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSwitch;
  final Widget child;

  const MainTabSwipeRegion({
    super.key,
    required this.currentIndex,
    required this.onSwitch,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    final content = route is MainTabRoute && animation != null
        ? ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(route.forward ? 1 : -1, 0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
              child: child,
            ),
          )
        : child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 220) return;
        final next = velocity < 0 ? currentIndex + 1 : currentIndex - 1;
        if (next >= 0 && next <= 3 && next != currentIndex) onSwitch(next);
      },
      child: content,
    );
  }
}
