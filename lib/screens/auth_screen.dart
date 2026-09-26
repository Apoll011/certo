import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/pill_icon.dart';
import '../widgets/primary_button.dart';

/// Email/password sign-in and sign-up.
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
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _signUpAsCaregiver = false;
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
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: AdaptiveContent(
          maxWidth: 480,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageX,
                  12,
                  AppSpacing.pageX,
                  8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: widget.onBack,
                  ),
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primaryContainer,
                          ),
                          child: const Center(
                            child: PillIcon(
                              size: 44,
                              color1: Colors.white,
                              color2: AppColors.primarySoft,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        _isSignUp ? l10n.authCreateAccount : l10n.authWelcome,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.authSubtitle,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      if (_isSignUp) ...[
                        _field(
                          controller: _nameController,
                          label: l10n.nameLabel,
                          hint: l10n.nameHint,
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _signUpAsCaregiver,
                          onChanged: (v) => setState(
                            () => _signUpAsCaregiver = v ?? false,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            'I\'m a caregiver',
                            style: textTheme.titleSmall,
                          ),
                          subtitle: Text(
                            'Family or professional — you can watch someone\'s adherence with their consent.',
                            style: textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _field(
                        controller: _emailController,
                        label: l10n.emailLabel,
                        hint: l10n.emailHint,
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        controller: _passwordController,
                        label: l10n.passwordLabel,
                        hint: l10n.passwordHint,
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: _message == l10n.authConfirmationSent
                                ? scheme.secondary
                                : scheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else
                        PrimaryButton(
                          label: _isSignUp ? l10n.signUp : l10n.signIn,
                          onPressed: _submit,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _isSignUp = !_isSignUp;
                                  _message = null;
                                }),
                        child: Text(
                          _isSignUp ? l10n.haveAccount : l10n.noAccount,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    Widget? suffix,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffix,
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
        ? await state.signUp(
            email,
            password,
            _nameController.text,
            asCaregiver: _signUpAsCaregiver,
          )
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
