import 'package:flutter/material.dart';

Route<void> mainTabRoute(Widget screen, {required bool forward}) {
  return MainTabRoute(screen, forward: forward);
}

/// Keeps the page scaffold stationary; only MainTabSwipeRegion slides in.
class MainTabRoute extends PageRouteBuilder<void> {
  final bool forward;

  MainTabRoute(Widget screen, {required this.forward})
    : super(
        pageBuilder: (_, animation, __) => screen,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) => child,
      );
}
