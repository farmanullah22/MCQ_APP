import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: size * 0.4,
                offset: Offset(0, size * 0.12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.grid_view_rounded, size: size * 0.52, color: AppColors.accent),
              Positioned(
                bottom: size * 0.12,
                right: size * 0.14,
                child: Container(
                  width: size * 0.22,
                  height: size * 0.22,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: size * 0.18),
        Text(
          'MCQ',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        Text(
          'Muallim Carpets',
          style: TextStyle(
            fontSize: size * 0.16,
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
