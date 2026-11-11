import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorder =
        isDark ? AppColors.surfaceBorder : AppColors.surfaceBorderLight;
    final defaultSurface =
        isDark ? AppColors.surface : AppColors.surfaceLight;

    final resolvedRadius = borderRadius ?? BorderRadius.circular(16);
    final shape = RoundedRectangleBorder(
      borderRadius: resolvedRadius,
      side: BorderSide(
        color: borderColor ?? defaultBorder,
        width: borderWidth,
      ),
    );

    final content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    final card = Material(
      color: color ?? defaultSurface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              customBorder: shape,
              child: content,
            )
          : content,
    );

    if (margin != null) {
      return Padding(padding: margin!, child: card);
    }
    return card;
  }
}

