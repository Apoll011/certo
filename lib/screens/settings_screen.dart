import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/alarm_sound_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';

/// Functional settings: language, profile name, account (sign out), about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final systemCode = View.of(context).platformDispatcher.locale.languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(
                      child: Text(l10n.settings, style: AppTheme.headerMedium),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _sectionLabel(l10n.profile),
                  AppCard(
                    child: Row(
                      children: [
                        _avatar(state.userName),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.userName, style: AppTheme.titleMedium),
                              if (state.userEmail != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  state.userEmail!,
                                  style: AppTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        CircleIconButton(
                          icon: Icons.edit_outlined,
                          size: 40,
                          onTap: () => _editName(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel(l10n.language),
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
                        _tileDivider(),
                        _languageTile(
                          context,
                          title: l10n.languageEnglish,
                          selected: state.localeOverride?.languageCode == 'en',
                          onTap: () => state.setLocale('en'),
                        ),
                        _tileDivider(),
                        _languageTile(
                          context,
                          title: l10n.languagePortuguese,
                          selected: state.localeOverride?.languageCode == 'pt',
                          onTap: () => state.setLocale('pt'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel(l10n.alarm),
                  const _AlarmSoundTile(),
                  const SizedBox(height: 24),
                  _sectionLabel(l10n.notifications),
                  AppCard(
                    onTap: () =>
                        _comingSoon(context, l10n.notificationsComingSoon),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n.notifications,
                            style: AppTheme.titleMedium,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                  if (state.isAuthenticated) ...[
                    const SizedBox(height: 24),
                    _sectionLabel(l10n.account),
                    AppCard(
                      onTap: () => _confirmSignOut(context),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              l10n.signOut,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _sectionLabel(l10n.about),
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.medication_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n.aboutBody,
                            style: AppTheme.bodyMedium,
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(), style: AppTheme.sectionLabel),
    );
  }

  Widget _avatar(String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
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
                  Text(title, style: AppTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.bodySmall),
                  ],
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F4));
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await state.updateUserName(name);
      if (context.mounted) {
        _comingSoon(context, l10n.nameSaved);
      }
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Leave settings before signing out so the user lands on onboarding.
      if (context.mounted) Navigator.of(context).pop();
      await state.signOut();
    }
  }

  void _comingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

/// Settings tile that opens the native Android alarm-sound picker and shows the
/// currently selected ringtone.
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
    if (picked == null || !mounted) return; // cancelled

    await state.setAlarmSound(picked);
    if (!mounted) return;
    _title = await AlarmSoundService.titleFor(picked);
    if (mounted) setState(() {});

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.alarmSoundSaved),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final subtitle = state.alarmSoundUri == null
        ? l10n.alarmSoundDefault
        : (_title ?? l10n.alarmSoundCustom);

    return AppCard(
      onTap: _pickAlarmSound,
      child: Row(
        children: [
          const Icon(
            Icons.music_note_rounded,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.alarmSound, style: AppTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 26,
          ),
        ],
      ),
    );
  }
}
