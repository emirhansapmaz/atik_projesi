import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class EcoTrackLogo extends StatelessWidget {
  static const String assetPath = 'assets/images/ecotrack_logo.png';

  final double size;
  final double borderRadius;
  final bool showBorder;

  const EcoTrackLogo({
    super.key,
    this.size = 40,
    this.borderRadius = 10,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'EcoTrack Logo',
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: AppColors.surfaceSubtle,
          child: Icon(
            Icons.eco_rounded,
            color: AppColors.primaryLight,
            size: size * 0.54,
          ),
        ),
      ),
    );

    if (!showBorder) {
      return Semantics(label: 'EcoTrack Logo', child: image);
    }

    return Semantics(
      label: 'EcoTrack Logo',
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(borderRadius + 1),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: image,
      ),
    );
  }
}

