import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Compact MCQ brand mark for AppBar leading / titles.
class AppBarBrand extends StatelessWidget {
  const AppBarBrand({super.key, this.size = 30, this.showText = true});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.emeraldGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.grid_view_rounded, size: size * 0.5, color: AppColors.accent),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            'MCQ',
            style: TextStyle(
              fontSize: size * 0.55,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}
