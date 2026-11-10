import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TableGoNavItem {
  const TableGoNavItem(this.icon, this.label, {this.activeIcon, this.badge = 0});
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int badge;
}

/// Bottom bar from the TableGo mockup: white bar with a thin top border,
/// the active tab is a peach rounded tile with orange icon + label.
class TableGoBottomNav extends StatelessWidget {
  const TableGoBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<TableGoNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == currentIndex;
              final color = active ? AppColors.primary : AppColors.textMuted;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label: item.label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.peach : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Badge(
                            isLabelVisible: item.badge > 0,
                            backgroundColor: AppColors.primary,
                            label: Text('${item.badge}'),
                            child: Icon(
                                active ? (item.activeIcon ?? item.icon) : item.icon,
                                size: 23,
                                color: color),
                          ),
                          const SizedBox(height: 4),
                          Text(item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight:
                                      active ? FontWeight.w700 : FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
