import 'package:flutter/material.dart';

import '../ai/tools/ui_tools.dart';
import 'pill_icon.dart';

/// Renders [ChatUiAttachment] blocks inside a voice/visual chat bubble.
class ChatUiAttachmentView extends StatelessWidget {
  const ChatUiAttachmentView({super.key, required this.attachment});

  final ChatUiAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return switch (attachment) {
      MedicationCardAttachment a => _MedicationChatCard(data: a),
      MedicationListAttachment a => _MedicationListChat(data: a),
      DoseStatusAttachment a => _DoseStatusChat(data: a),
    };
  }
}

class _MedicationChatCard extends StatelessWidget {
  const _MedicationChatCard({required this.data});
  final MedicationCardAttachment data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PillIcon(colorIndex: data.pillColorIndex, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data.badge != null && data.badge!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _MiniBadge(
                        label: data.badge!,
                        color: const Color(0xFF3366FF),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (data.dosage.isNotEmpty) data.dosage,
                    if (data.instruction.isNotEmpty) data.instruction,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (data.highlight != null && data.highlight!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: Color(0xFF4338CA),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data.highlight!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3730A3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (data.times.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in data.times.take(4))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (data.category.isNotEmpty ||
                    data.isTakenToday ||
                    data.isSnoozed) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (data.category.isNotEmpty)
                        Text(
                          data.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (data.isTakenToday)
                        const _MiniBadge(
                          label: 'Taken today',
                          color: Color(0xFF15803D),
                        ),
                      if (data.isSnoozed)
                        const _MiniBadge(
                          label: 'Snoozed',
                          color: Color(0xFFB45309),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationListChat extends StatelessWidget {
  const _MedicationListChat({required this.data});
  final MedicationListAttachment data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < data.items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _MedicationChatCard(data: data.items[i]),
        ],
      ],
    );
  }
}

class _DoseStatusChat extends StatelessWidget {
  const _DoseStatusChat({required this.data});
  final DoseStatusAttachment data;

  Color get _toneColor => switch (data.tone) {
        'warning' => const Color(0xFFB45309),
        'danger' => const Color(0xFFB91C1C),
        'info' => const Color(0xFF1D4ED8),
        _ => const Color(0xFF15803D),
      };

  Color get _toneBg => switch (data.tone) {
        'warning' => const Color(0xFFFFF7ED),
        'danger' => const Color(0xFFFEF2F2),
        'info' => const Color(0xFFEFF6FF),
        _ => const Color(0xFFF0FDF4),
      };

  IconData get _toneIcon => switch (data.tone) {
        'warning' => Icons.snooze_rounded,
        'danger' => Icons.cancel_rounded,
        'info' => Icons.info_rounded,
        _ => Icons.check_circle_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _toneColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _toneBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          PillIcon(colorIndex: data.pillColorIndex, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.medicationName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(_toneIcon, size: 15, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data.statusLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (data.detail != null && data.detail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    data.detail!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
