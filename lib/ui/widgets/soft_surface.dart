import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Светлый фон без фото: мягкие зелёные пятна на мятном градиенте.
/// Общий для входа и профиля — сквозь матовые панели пятна видны размытыми.
class SoftBackdrop extends StatelessWidget {
  const SoftBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    Widget blob(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
    final dark = AppColors.dark;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [
                            Color(0xFF0F1513),
                            Color(0xFF131A17),
                            Color(0xFF0E1517),
                          ]
                        : const [
                            Color(0xFFEAF7EE),
                            Color(0xFFF7FBF8),
                            Color(0xFFE3F2F0),
                          ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -w * 0.35,
              top: -h * 0.12,
              child: blob(
                w * 1.1,
                Color(dark ? 0x402E9F46 : 0x8C7FD68F),
              ),
            ),
            Positioned(
              right: -w * 0.4,
              top: h * 0.28,
              child: blob(
                w * 1.0,
                Color(dark ? 0x331E8C80 : 0x7357C4B8),
              ),
            ),
            Positioned(
              left: -w * 0.2,
              bottom: -h * 0.1,
              child: blob(
                w * 1.0,
                Color(dark ? 0x2A6C8F2E : 0x80B9E27A),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Матовое стекло: размытие, белая дымка и светлая кромка.
class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.blur = 36,
    this.opacity = 0.72,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;

  /// Насколько бело стекло (сверху; снизу — чуть прозрачнее).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1E5A2C),
            blurRadius: 36,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.glass(opacity),
                  AppColors.glass(opacity - 0.2),
                ],
              ),
              border: Border.all(
                color: AppColors.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1.4,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
