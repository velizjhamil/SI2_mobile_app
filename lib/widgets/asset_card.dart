import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class AssetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String percentageChange;
  final String amount;
  final String portfolioShare;
  final IconData icon;
  final bool isHighlighted;

  const AssetCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.percentageChange,
    required this.amount,
    required this.portfolioShare,
    required this.icon,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isHighlighted ? AppColors.softGreen : AppColors.surfaceContainerLow;
    final textColor = isHighlighted ? AppColors.graphite : AppColors.onSurface;
    final subtextColor = isHighlighted ? AppColors.graphite.withOpacity(0.7) : AppColors.onSurfaceVariant;
    final isPos = percentageChange.startsWith('+');

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? Colors.transparent : AppColors.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isHighlighted ? AppColors.forestGreen : AppColors.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: isHighlighted ? Colors.white : AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPos ? AppColors.primaryContainer.withOpacity(0.2) : Colors.pink.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  percentageChange,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPos ? (isHighlighted ? AppColors.forestGreen : AppColors.primary) : Colors.pinkAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amount,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  Text(
                    portfolioShare,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.65,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isHighlighted ? AppColors.forestGreen : AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
