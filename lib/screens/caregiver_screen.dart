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

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(state),
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            ScreenHeader(
              title: 'Caregiver',
              large: true,
              trailing: IconButton(
                tooltip: 'Sharing & invites',
                onPressed: () => _openSharingSheet(context, state),
                icon: Icon(Icons.shield_outlined, color: scheme.onSurface),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!state.isAuthenticated)
              _signedOutCard(context)
            else if (!state.isCaregiver)
              _enableCaregiverCard(context, state)
            else ...[
              Text(
                'People you support',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'One glance per person — green means every scheduled dose was confirmed, yellow means uncertain, red means missed or mismatched.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_refreshing && state.careRecipients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.careRecipients.isEmpty)
                EmptyState(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Add someone you care for',
                  subtitle:
                      'Ask them to share an invite code from Settings → Sharing. You\'ll see their adherence calendar here — with their explicit, revocable consent.',
                  iconColor: scheme.secondary,
                  iconBackground: scheme.secondaryContainer,
                )
              else
                for (final link in state.careRecipients) ...[
                  _RecipientCard(
                    link: link,
                    snapshot: state.careSnapshots[link.id],
                    onOpen: () => _openDetail(context, state, link),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Add with invite code',
                icon: Icons.qr_code_rounded,
                onPressed: () => _redeemInvite(context, state),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _signedOutCard(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Sign in for caregiver mode',
      subtitle:
          'Caregiver mode needs an account so consent and adherence stay private and revocable.',
    );
  }

  Widget _enableCaregiverCard(BuildContext context, AppState state) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.favorite_outline_rounded,
                    color: scheme.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Turn on caregiver mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'For family or professional aides. With the other person\'s consent you can see a color-coded calendar of their verification history — without taking over their independence.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'I\'m a caregiver',
            onPressed: () async {
              await state.setCaregiverMode(true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Caregiver mode enabled'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
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

  Future<void> _openSharingSheet(BuildContext context, AppState state) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SharingSheet(state: state),
    );
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
        AdherenceDayTone.good => 'all confirmed',
        AdherenceDayTone.uncertain => 'needs a look',
        AdherenceDayTone.alert => 'missed / mismatch',
        AdherenceDayTone.none => 'no data yet',
      };
}

class _SharingSheet extends StatefulWidget {
  const _SharingSheet({required this.state});
  final AppState state;

  @override
  State<_SharingSheet> createState() => _SharingSheetState();
}

class _SharingSheetState extends State<_SharingSheet> {
  String? _inviteCode;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sharing & consent',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You stay in control. Generate a code for someone you trust. You can revoke access anytime — visibility is always explicit and revocable.',
              style: TextStyle(color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 16),
            if (!state.isAuthenticated)
              const Text('Sign in to manage sharing.')
            else ...[
              PrimaryButton(
                label: _busy ? 'Creating…' : 'Generate invite code',
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final link = await state.createCaregiverInvite();
                          setState(() => _inviteCode = link?.inviteCode);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
              if (_inviteCode != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _inviteCode!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _inviteCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Code copied'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Who can see my adherence',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              if (state.grantedCareLinks
                  .where((l) => l.status != CaregiverLinkStatus.revoked)
                  .isEmpty)
                const Text(
                  'No one yet. Share a code when you\'re ready.',
                  style: TextStyle(color: Color(0xFF64748B)),
                )
              else
                for (final link in state.grantedCareLinks.where(
                  (l) => l.status != CaregiverLinkStatus.revoked,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      link.status == CaregiverLinkStatus.pending
                          ? 'Pending · ${link.inviteCode}'
                          : (link.caregiverName.isNotEmpty
                              ? link.caregiverName
                              : 'Caregiver'),
                    ),
                    subtitle: Text(
                      link.status == CaregiverLinkStatus.active
                          ? 'Active access'
                          : 'Waiting for caregiver to redeem',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        await state.revokeCaregiverAccess(link.id);
                        if (context.mounted) setState(() {});
                      },
                      child: const Text('Revoke'),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
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
                                  'Last 4 weeks of verification. Green = all doses confirmed, yellow = uncertain, red = missed or mismatch.',
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
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF15803D),
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

