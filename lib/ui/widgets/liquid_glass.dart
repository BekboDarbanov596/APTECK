import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Матовая прозрачная поверхность с размытием и двойным световым краем.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 26,
    this.dark = false,
  });
  final Widget child;
  final double radius;
  final bool dark;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: dark ? 0.28 : 0.85),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: dark ? 0.16 : 0.65),
              Colors.white.withValues(alpha: dark ? 0.04 : 0.24),
              Colors.white.withValues(alpha: dark ? 0.10 : 0.48),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: child,
      ),
    ),
  );
}
