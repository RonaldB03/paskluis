import 'package:flutter/material.dart';

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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 220) return;
        final next = velocity < 0 ? currentIndex + 1 : currentIndex - 1;
        if (next >= 0 && next <= 3 && next != currentIndex) onSwitch(next);
      },
      child: child,
    );
  }
}
