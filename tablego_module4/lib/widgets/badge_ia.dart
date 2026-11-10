import 'package:flutter/material.dart';
import '../couleurs.dart';

// charte figma : toute fonction IA a une etincelle + un badge "IA"
class BadgeIA extends StatelessWidget {
  const BadgeIA({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: orangeClair,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: orange, size: 14),
          SizedBox(width: 4),
          Text('IA',
              style: TextStyle(
                  color: orange, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
