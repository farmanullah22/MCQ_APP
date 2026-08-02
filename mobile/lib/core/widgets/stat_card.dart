import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.trend,
    this.trendUp,
    this.onTap,
    this.valueType = StatValueType.currency,
  });

  final String title;
  final num value;
  final IconData icon;

  /// Accent color for the icon, chip and decorative gradient.
  final Color? color;

  final String? subtitle;

  /// Optional trend indicator text, e.g. "+12%" or "-3%".
  final String? trend;

  /// Whether the trend is positive (green) or negative (red).
  final bool? trendUp;

  final VoidCallback? onTap;
  final StatValueType valueType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = color ?? AppColors.primary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final displayValue = switch (valueType) {
      StatValueType.currency => Formatters.currency(value),
      StatValueType.number => Formatters.number(value),
      StatValueType.plain => '${value.round()}',
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: isDark ? 0.22 : 0.12),
                theme.colorScheme.surface,
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.30 : 0.22),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -22,
                top: -26,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.10 : 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accent.withValues(alpha: 0.72)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.32),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 19, color: Colors.white),
                      ),
                      if (trend != null && trendUp != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: (trendUp! ? AppColors.success : AppColors.danger)
                                .withValues(alpha: isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                trendUp! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 11,
                                color: trendUp! ? AppColors.success : AppColors.danger,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                trend!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: trendUp! ? AppColors.success : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum StatValueType { currency, number, plain }
