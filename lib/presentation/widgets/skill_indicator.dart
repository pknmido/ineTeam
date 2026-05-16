import 'package:flutter/material.dart';
import '../../core/utils/helpers.dart';

/// Visual indicator for a player's skill level.
class SkillIndicator extends StatelessWidget {
  final int? skillLevel;
  final double size;
  final bool showLabel;

  const SkillIndicator({
    super.key,
    required this.skillLevel,
    this.size = 40,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = skillLevel != null ? Helpers.skillColor(skillLevel!) : Colors.grey;
    final label = skillLevel != null ? Helpers.skillLabel(skillLevel!) : 'Unrated';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ring
              CircularProgressIndicator(
                value: skillLevel != null ? skillLevel! / 100 : 0.0,
                strokeWidth: 3,
                backgroundColor: color.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              // Number in center
              Text(
                skillLevel != null ? '$skillLevel' : '-',
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}
