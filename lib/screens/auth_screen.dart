import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/gradient_orb.dart';
import '../widgets/pill_icon.dart';
import '../widgets/primary_button.dart';

/// Email/password sign-in and sign-up. On success, [AppState] flips to
/// signed-in and the root swaps to [MainShell] — no manual navigation needed.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
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
                    onTap: widget.onBack,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: GradientOrb(
                      size: 120,
                      blur: 40,
                      spread: 10,
                      child: const Center(
                        child: PillIcon(
                          size: 52,
                          color1: Colors.white,
                          color2: Color(0xFFE2EBF7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _isSignUp ? l10n.authCreateAccount : l10n.authWelcome,
                    textAlign: TextAlign.center,
                    style: AppTheme.headerLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  if (_isSignUp) ...[
                    _field(
                      controller: _nameController,
                      label: l10n.nameLabel,
                      hint: l10n.nameHint,
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _field(
                    controller: _emailController,
                    label: l10n.emailLabel,
                    hint: l10n.emailHint,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _passwordController,
                    label: l10n.passwordLabel,
                    hint: l10n.passwordHint,
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message == l10n.authConfirmationSent
                            ? AppColors.info
                            : AppColors.danger,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  else
                    PrimaryButton(
                      label: _isSignUp ? l10n.signUp : l10n.signIn,
                      onPressed: _submit,
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _message = null;
                          }),
                    child: Text(
                      _isSignUp ? l10n.haveAccount : l10n.noAccount,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodySmall),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = l10n.authFillAll);
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    final state = context.read<AppState>();
    final result = _isSignUp
        ? await state.signUp(email, password, _nameController.text)
        : await state.signIn(email, password);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result == 'confirmation-required') {
        _message = l10n.authConfirmationSent;
      } else if (result != null) {
        _message = result;
      }
    });
  }
}
