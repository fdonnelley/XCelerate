import 'package:flutter/material.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';

class PlaceNumber extends StatelessWidget {
  const PlaceNumber({
    super.key,
    required this.place,
    required this.color,
  });
  final int place;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          '#$place',
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class RunnerInfo extends StatelessWidget {
  const RunnerInfo({
    super.key,
    required this.runner,
    required this.accentColor,
  });
  final RunnerRecord runner;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          runner.name,
          style: AppTypography.bodySemibold.copyWith(
            color: AppColors.darkColor,
            fontSize: 14,
            letterSpacing: -0.1,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (runner.bib.isNotEmpty)
              InfoChip(label: 'Bib ${runner.bib}', color: accentColor),
            if (runner.school.isNotEmpty)
              InfoChip(
                  label: runner.school,
                  color: AppColors.mediumColor.withOpacity(0.8)),
          ],
        ),
      ],
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    required this.color,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: -0.1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
