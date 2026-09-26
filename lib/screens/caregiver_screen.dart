import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/caregiver.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../widgets/adherence_heatmap.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/pill_icon.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Caregiver tab — manage people you support + adherence heatmaps.
class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.isAuthenticated) {
        unawaited(_refresh(state));
      }
    });
  }

  Future<void> _refresh(AppState state) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await state.refreshCaregiverData();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();
    final isCaregiverView = state.careRecipients.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(state),
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              canPop
                  ? ScreenHeader.back(
                      title: isCaregiverView ? 'Caregiver' : 'Sharing',
                      onBack: () => Navigator.of(context).pop(),
                    )
                  : ScreenHeader(
                      title: isCaregiverView ? 'Caregiver' : 'Sharing',
                      large: true,
                    ),
              const SizedBox(height: AppSpacing.sm),
              if (!state.isAuthenticated)
                _signedOutCard(context)
              else ...[
                if (!isCaregiverView) ...[
                  Text(
                    'Create a code for someone to help you, or redeem a code to support someone else.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Create invite code',
                    icon: Icons.mail_outline_rounded,
                    onPressed: () => _createInvite(context, state),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Redeem invite code',
                    icon: Icons.person_add_alt_1_rounded,
                    filled: false,
                    onPressed: () => _redeemInvite(context, state),
                  ),
                ] else ...[
                  Text(
                    'Green = all taken · Yellow = some taken · Red = missed or problem',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_refreshing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  for (final link in state.careRecipients) ...[
                    _RecipientCard(
                      link: link,
                      snapshot: state.careSnapshots[link.id],
                      onOpen: () => _openDetail(context, state, link),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Create invite code',
                    icon: Icons.mail_outline_rounded,
                    filled: false,
                    onPressed: () => _createInvite(context, state),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Redeem invite code',
                    icon: Icons.person_add_alt_1_rounded,
                    filled: false,
                    onPressed: () => _redeemInvite(context, state),
                  ),
                ],
                if (state.grantedCareLinks
                    .where((l) => l.status != CaregiverLinkStatus.revoked)
                    .isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'People with access to you',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final link in state.grantedCareLinks.where(
                    (l) => l.status != CaregiverLinkStatus.revoked,
                  ))
                    _grantedLinkTile(context, state, link),
                ],
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grantedLinkTile(
    BuildContext context,
    AppState state,
    CaregiverLink link,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.status == CaregiverLinkStatus.pending
                        ? 'Code ${link.inviteCode}'
                        : (link.caregiverName.isNotEmpty
                            ? link.caregiverName
                            : 'Caregiver connected'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    link.status == CaregiverLinkStatus.active
                        ? 'Can view your adherence'
                        : 'Waiting for them to redeem',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (link.status == CaregiverLinkStatus.pending)
              IconButton(
                tooltip: 'Copy code',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            TextButton(
              onPressed: () async {
                await state.revokeCaregiverAccess(link.id);
              },
              child: const Text('Revoke'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signedOutCard(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Sign in to share',
      subtitle:
          'Create or redeem invite codes after you sign in — consent stays private and revocable.',
    );
  }

  Future<void> _createInvite(BuildContext context, AppState state) async {
    try {
      final link = await state.createCaregiverInvite();
      if (!context.mounted || link == null) return;
      await Clipboard.setData(ClipboardData(text: link.inviteCode));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invite code ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this code with your caregiver. Copied to clipboard.',
              ),
              const SizedBox(height: 12),
              SelectableText(
                link.inviteCode,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _redeemInvite(BuildContext context, AppState state) async {
    final codeCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add with invite code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite code',
                hintText: 'VER-XXXX',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Name for them (optional)',
                hintText: 'Mom, Mrs. Silva…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await state.redeemCaregiverInvite(
        code: codeCtrl.text,
        label: labelCtrl.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected — they can revoke access anytime'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openDetail(
    BuildContext context,
    AppState state,
    CaregiverLink link,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CareRecipientDetailScreen(linkId: link.id),
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.link,
    required this.snapshot,
    required this.onOpen,
  });

  final CaregiverLink link;
  final CareRecipientSnapshot? snapshot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tone = snapshot?.todayTone ?? AdherenceDayTone.none;
    final toneColor = AdherenceHeatmap.colorFor(tone);
    final medCount = snapshot?.activeMedCount ?? 0;

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: toneColor.withValues(alpha: 0.2),
                  child: Text(
                  link.displayName.isNotEmpty
                      ? link.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: toneColor == const Color(0xFFE2E8F0)
                        ? const Color(0xFF334155)
                        : toneColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      medCount == 0
                          ? 'Tap to refresh adherence'
                          : '$medCount active medication${medCount == 1 ? '' : 's'} · today: ${_toneLabel(tone)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          if (snapshot != null && snapshot!.heatmap.isNotEmpty) ...[
            const SizedBox(height: 14),
            AdherenceHeatmap(days: snapshot!.heatmap),
          ],
        ],
      ),
    );
  }

  String _toneLabel(AdherenceDayTone tone) => switch (tone) {
        AdherenceDayTone.good => 'all taken',
        AdherenceDayTone.uncertain => 'some taken',
        AdherenceDayTone.alert => 'missed / problem',
        AdherenceDayTone.none => 'no data yet',
      };
}

/// Detail view for one care recipient — heatmap + meds + mark taken.
class CareRecipientDetailScreen extends StatefulWidget {
  const CareRecipientDetailScreen({super.key, required this.linkId});
  final String linkId;

  @override
  State<CareRecipientDetailScreen> createState() =>
      _CareRecipientDetailScreenState();
}

class _CareRecipientDetailScreenState extends State<CareRecipientDetailScreen> {
  bool _loading = true;
  CareRecipientSnapshot? _snap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    setState(() => _loading = true);
    final snap = await state.loadCareRecipient(widget.linkId);
    if (mounted) {
      setState(() {
        _snap = snap ?? state.careSnapshots[widget.linkId];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final link = state.careRecipients.cast<CaregiverLink?>().firstWhere(
          (l) => l?.id == widget.linkId,
          orElse: () => null,
        );
    final snap = _snap ?? state.careSnapshots[widget.linkId];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                12,
                AppSpacing.pageX,
                8,
              ),
              child: ScreenHeader.back(
                title: link?.displayName ?? 'Care recipient',
                onBack: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: _loading && snap == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: AppSpacing.pagePaddingTight,
                        children: [
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Adherence calendar',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Green = all taken · Yellow = some taken · Red = missed or problem. Based on the latest action per medication each day.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (snap != null)
                                  AdherenceHeatmap(days: snap.heatmap)
                                else
                                  const Text('No heatmap data yet.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Medications',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          if (snap == null || snap.medications.isEmpty)
                            const Text(
                              'No medications on their list yet.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            )
                          else
                            for (final med in snap.medications.where(
                              (m) => m.status == MedicationStatus.active,
                            )) ...[
                              AppCard(
                                child: Row(
                                  children: [
                                    PillIcon(
                                      colorIndex: med.pillColorIndex,
                                      size: 44,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            med.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            med.dosageLine,
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            med.timesLine,
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (snap.takenTodayIds.contains(med.id))
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF15803D),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Taken',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      TextButton(
                                        onPressed: () async {
                                          await state.markTakenForPatient(
                                            patientId: snap.link.patientId,
                                            medicationId: med.id,
                                            linkId: widget.linkId,
                                          );
                                          await _load();
                                        },
                                        child: const Text('Mark taken'),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

