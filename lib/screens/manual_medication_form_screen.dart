import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/schedule.dart';
import '../utils/status.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/primary_button.dart';

/// Manual "add medication" form. Pass [medication] to edit an existing one;
/// otherwise it creates a new medication. Saves through [AppState], which
/// writes to Supabase when signed in and to local state otherwise.
class ManualMedicationFormScreen extends StatefulWidget {
  const ManualMedicationFormScreen({super.key, this.medication});

  /// When non-null, the form is pre-filled and saves via update.
  final Medication? medication;

  @override
  State<ManualMedicationFormScreen> createState() =>
      _ManualMedicationFormScreenState();
}

class _ManualMedicationFormScreenState
    extends State<ManualMedicationFormScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();

  final List<String> _times = [];
  int _frequencyDays = 1;
  int _pillColorIndex = 0;
  MedicationStatus _status = MedicationStatus.active;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    if (m == null) return;
    _nameController.text = m.name;
    _dosageController.text = m.dosage;
    _instructionController.text = m.instruction;
    _categoryController.text = m.category;
    _notesController.text = m.notes;
    _times.addAll(m.times);
    _frequencyDays = m.frequencyDays;
    _pillColorIndex = m.pillColorIndex;
    _status = m.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                      child: Text(
                        _isEditing ? l10n.editMedication : l10n.addMedication,
                        style: AppTheme.headerMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  _field(
                    l10n.medicationName,
                    _nameController,
                    hint: l10n.medicationNameHint,
                    icon: Icons.medication_outlined,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    l10n.dosage,
                    _dosageController,
                    hint: l10n.dosageHint,
                    icon: Icons.scale_outlined,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    l10n.instruction,
                    _instructionController,
                    hint: l10n.instructionHint,
                    icon: Icons.restaurant_outlined,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    l10n.category,
                    _categoryController,
                    hint: l10n.categoryHint,
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    l10n.notes,
                    _notesController,
                    hint: l10n.notesHint,
                    icon: Icons.sticky_note_2_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  _frequencySection(l10n),
                  const SizedBox(height: 24),
                  _timesSection(l10n),
                  const SizedBox(height: 24),
                  _colorSection(l10n),
                  const SizedBox(height: 24),
                  _statusSection(l10n),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: PrimaryButton(
                label: l10n.saveMedication,
                icon: _saving ? null : Icons.check_rounded,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodySmall),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _frequencySection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.frequency, style: AppTheme.bodySmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in const [1, 2, 3, 7])
              ChoiceChip(
                label: Text(_frequencyLabel(l10n, days)),
                selected: _frequencyDays == days,
                onSelected: (_) => setState(() => _frequencyDays = days),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _frequencyDays == days
                      ? Colors.white
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }

  String _frequencyLabel(AppLocalizations l10n, int days) =>
      days == 1 ? l10n.everyDay : l10n.everyNDays(days);

  Widget _timesSection(AppLocalizations l10n) {
    final clockTimes = _times.where((t) => !isMealToken(t)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.times, style: AppTheme.bodySmall),
        const SizedBox(height: 10),
        // Meal anchors (breakfast / lunch / dinner).
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final token in const ['breakfast', 'lunch', 'dinner'])
              FilterChip(
                label: Text(displayTime(token, l10n)),
                selected: _times.contains(token),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    if (!_times.contains(token)) _times.add(token);
                  } else {
                    _times.remove(token);
                  }
                  _sortTimes();
                }),
                selectedColor: AppColors.primarySoft,
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _times.contains(token)
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (clockTimes.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final time in clockTimes)
                InputChip(
                  label: Text(time),
                  onDeleted: () => setState(() => _times.remove(time)),
                  deleteIconColor: AppColors.textSecondary,
                  backgroundColor: AppColors.primarySoft,
                  labelStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addTime,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(l10n.addTime),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }

  Widget _colorSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pillColor, style: AppTheme.bodySmall),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < AppColors.pillPalette.length; i++)
              GestureDetector(
                onTap: () => setState(() => _pillColorIndex = i),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.pillPalette[i][0],
                        AppColors.pillPalette[i][1],
                      ],
                    ),
                    border: _pillColorIndex == i
                        ? Border.all(color: AppColors.primary, width: 3)
                        : null,
                  ),
                  child: _pillColorIndex == i
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.status, style: AppTheme.bodySmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in MedicationStatus.values)
              ChoiceChip(
                label: Text(statusLabel(l10n, s)),
                avatar: Icon(
                  statusIcon(s),
                  size: 18,
                  color: _status == s ? Colors.white : statusColor(s),
                ),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
                selectedColor: statusColor(s),
                labelStyle: TextStyle(
                  color: _status == s ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _addTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked == null) return;
    final formatted = _formatTime(picked);
    if (_times.contains(formatted)) return;
    setState(() {
      _times.add(formatted);
      _sortTimes();
    });
  }

  void _sortTimes() {
    _times.sort(
      (a, b) => resolveTimeMinutes(a).compareTo(resolveTimeMinutes(b)),
    );
  }

  String _formatTime(TimeOfDay t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $ampm';
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.fillRequired);
      return;
    }
    if (_times.isEmpty) {
      setState(() => _error = l10n.addAtLeastOneTime);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final state = context.read<AppState>();
    final existing = widget.medication;

    if (existing == null) {
      final med = Medication(
        id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        dosage: _dosageController.text.trim(),
        instruction: _instructionController.text.trim(),
        category: _categoryController.text.trim(),
        notes: _notesController.text.trim(),
        times: List.of(_times),
        pillColorIndex: _pillColorIndex,
        status: _status,
        startedAt: DateTime.now(),
        frequencyDays: _frequencyDays,
      );
      await state.addMedication(med);
    } else {
      await state.updateMedication(
        existing.copyWith(
          name: name,
          dosage: _dosageController.text.trim(),
          instruction: _instructionController.text.trim(),
          category: _categoryController.text.trim(),
          notes: _notesController.text.trim(),
          times: List.of(_times),
          pillColorIndex: _pillColorIndex,
          status: _status,
          frequencyDays: _frequencyDays,
        ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? l10n.medicationSaved : l10n.medicationUpdated,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    Navigator.of(context).pop();
  }
}
