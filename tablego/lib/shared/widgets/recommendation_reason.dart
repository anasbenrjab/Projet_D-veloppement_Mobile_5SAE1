import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The "why" line of a recommendation: a small ✨ icon and a short French
/// explanation ("Parce que vous aimez la cuisine japonaise · Compatible
/// halal").
class RecommendationReason extends StatelessWidget {
  const RecommendationReason(this.text, {super.key, this.maxLines = 2});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, height: 1.3, color: AppColors.grey700),
          ),
        ),
      ],
    );
  }
}
