import 'package:flutter/material.dart';

import '../models/caregiver.dart';

/// 7-column calendar heatmap of adherence (green / yellow / red / none).
class AdherenceHeatmap extends StatelessWidget {
  const AdherenceHeatmap({
    super.key,
    required this.days,
    this.onDayTap,
  });

  final List<AdherenceDay> days;
  final void Function(AdherenceDay day)? onDayTap;

  static Color colorFor(AdherenceDayTone tone) => switch (tone) {
        AdherenceDayTone.good => const Color(0xFF22C55E),
        AdherenceDayTone.uncertain => const Color(0xFFEAB308),
        AdherenceDayTone.alert => const Color(0xFFEF4444),
        AdherenceDayTone.none => const Color(0xFFE2E8F0),
      };

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 4.0;
            final cell = ((constraints.maxWidth - gap * 6) / 7).clamp(14.0, 36.0);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final day in days)
                  GestureDetector(
                    onTap: onDayTap == null ? null : () => onDayTap!(day),
                    child: Tooltip(
                      message:
                          '${day.date.month}/${day.date.day}: ${day.summary}',
                      child: Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: colorFor(day.tone),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _Legend(color: Color(0xFF22C55E), label: 'All confirmed'),
            _Legend(color: Color(0xFFEAB308), label: 'Uncertain'),
            _Legend(color: Color(0xFFEF4444), label: 'Missed / mismatch'),
            _Legend(color: Color(0xFFE2E8F0), label: 'No data'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
