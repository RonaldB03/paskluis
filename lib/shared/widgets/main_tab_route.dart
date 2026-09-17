import 'package:flutter/material.dart';

Route<void> mainTabRoute(Widget screen, {required bool forward}) {
  return PageRouteBuilder<void>(
    pageBuilder: (_, animation, __) => screen,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, animation, __, child) {
      final begin = Offset(forward ? 1 : -1, 0);
      final slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      );
      return SlideTransition(position: slide, child: child);
    },
  );
}
