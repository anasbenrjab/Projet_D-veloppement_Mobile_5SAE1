import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// TableGo brand mark: orange rounded square with a pin + fork/knife and
/// a small eco leaf, optionally followed by the wordmark.
class TableGoLogo extends StatelessWidget {
  const TableGoLogo({
    super.key,
    this.size = 34,
    this.showText = true,
    this.textColor = AppColors.primary,
  });

  final double size;
  final bool showText;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.location_on, color: Colors.white, size: size * 0.72),
                Padding(
                  padding: EdgeInsets.only(bottom: size * 0.12),
                  child: Icon(Icons.restaurant,
                      color: AppColors.primary, size: size * 0.26),
                ),
              ],
            ),
          ),
          Positioned(
            top: -size * 0.12,
            right: -size * 0.12,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: size * 0.04),
              ),
              child: Icon(Icons.eco, color: Colors.white, size: size * 0.24),
            ),
          ),
        ],
      ),
    );

    if (!showText) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.3),
        Text('TableGo',
            style: GoogleFonts.poppins(
                fontSize: size * 0.6,
                fontWeight: FontWeight.w700,
                color: textColor)),
      ],
    );
  }
}
