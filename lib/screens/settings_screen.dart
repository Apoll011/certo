import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/alarm_service.dart';
import '../services/alarm_sound_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/screen_header.dart';

/// Settings: language, profile, alarms, account.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final systemCode = View.of(context).platformDispatcher.locale.languageCode;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                12,
                AppSpacing.pageX,
                AppSpacing.sm,
              ),
              child: ScreenHeader.back(
                title: l10n.settings,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: AppSpacing.pagePaddingTight,
                children: [
                  _sectionLabel(context, l10n.profile),
                  AppCard(
                    child: Row(
                      children: [
                        _avatar(context, state.userName),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.userName, style: textTheme.titleMedium),
                              if (state.userEmail != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  state.userEmail!,
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        CircleIconButton(
                          icon: Icons.edit_outlined,
                          size: 40,
                          tooltip: l10n.editName,
                          onTap: () => _editName(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _sectionLabel(context, l10n.language),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _languageTile(
                          context,
                          title: l10n.languageSystem,
                          subtitle: systemCode == 'pt'
                              ? l10n.languagePortuguese
                              : l10n.languageEnglish,
                          selected: state.localeOverride == null,
                          onTap: () => state.setLocale(null),
                        ),
                        Divider(color: scheme.outlineVariant, height: 1),
                        _languageTile(
                          context,
                          title: l10n.languageEnglish,
                          selected: state.localeOverride?.languageCode == 'en',
                          onTap: () => state.setLocale('en'),
                        ),
                        Divider(color: scheme.outlineVariant, height: 1),
                        _languageTile(
                          context,
                          title: l10n.languagePortuguese,
                          selected: state.localeOverride?.languageCode == 'pt',
                          onTap: () => state.setLocale('pt'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _sectionLabel(context, l10n.alarm),
                  const _AlarmSoundTile(),
                  const SizedBox(height: AppSpacing.sm),
                  const _FullScreenAlarmTile(),
                  const SizedBox(height: AppSpacing.xxl),
                  _sectionLabel(context, l10n.notifications),
                  AppCard(
                    onTap: () =>
                        _toast(context, l10n.notificationsComingSoon),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          color: scheme.onSurface,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n.notifications,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                  if (state.isAuthenticated) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    _sectionLabel(context, l10n.account),
                    AppCard(
                      onTap: () => _confirmSignOut(context),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, color: scheme.error),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              l10n.signOut,
                              style: textTheme.titleMedium?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  _sectionLabel(context, l10n.about),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.medication_rounded,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n.aboutBody,
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _avatar(BuildContext context, String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _languageTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<AppState>();
    final controller = TextEditingController(text: state.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editName),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: l10n.nameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await state.updateUserName(name);
      if (context.mounted) _toast(context, l10n.nameSaved);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (context.mounted) Navigator.of(context).pop();
      await state.signOut();
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AlarmSoundTile extends StatefulWidget {
  const _AlarmSoundTile();

  @override
  State<_AlarmSoundTile> createState() => _AlarmSoundTileState();
}

class _AlarmSoundTileState extends State<_AlarmSoundTile> {
  String? _title;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTitle();
  }

  Future<void> _loadTitle() async {
    final uri = context.read<AppState>().alarmSoundUri;
    if (uri == null) {
      if (_title != null && mounted) setState(() => _title = null);
      return;
    }
    final title = await AlarmSoundService.titleFor(uri);
    if (mounted && title != null && title != _title) {
      setState(() => _title = title);
    }
  }

  Future<void> _pickAlarmSound() async {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final picked = await AlarmSoundService.pick();
    if (picked == null || !mounted) return;

    await state.setAlarmSound(picked);
    if (!mounted) return;
    _title = await AlarmSoundService.titleFor(picked);
    if (mounted) setState(() {});

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.alarmSoundSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = state.alarmSoundUri == null
        ? l10n.alarmSoundDefault
        : (_title ?? l10n.alarmSoundCustom);

    return AppCard(
      onTap: _pickAlarmSound,
      child: Row(
        children: [
          Icon(Icons.music_note_rounded, color: scheme.onSurface),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.alarmSound, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant,
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _FullScreenAlarmTile extends StatefulWidget {
  const _FullScreenAlarmTile();

  @override
  State<_FullScreenAlarmTile> createState() => _FullScreenAlarmTileState();
}

class _FullScreenAlarmTileState extends State<_FullScreenAlarmTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await AlarmService.canUseFullScreenIntent();
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _onTap() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final enabled = await AlarmService.requestFullScreenIntentPermission();
    if (!mounted) return;
    setState(() => _enabled = enabled);

    if (enabled) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.alarmFullScreenEnabled)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = _enabled ?? true;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: _onTap,
      child: Row(
        children: [
          Icon(
            Icons.fullscreen_rounded,
            color: enabled ? AppColors.success : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.alarmFullScreen, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  enabled ? l10n.alarmFullScreenOn : l10n.alarmFullScreenOff,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
            color: enabled ? AppColors.success : scheme.onSurfaceVariant,
            size: 26,
          ),
        ],
      ),
    );
  }
}
