import 'package:flutter/material.dart';
import 'package:trader_log/theme/ledger_theme.dart';

/// Screen 1 — "Log In" (Terminal Authentication).
class LoginStep extends StatefulWidget {
  final bool loading;
  final String? error;
  final Future<void> Function({
    required String email,
    required String password,
    required bool trustTerminal,
  }) onSubmit;
  final VoidCallback onCreateAccount;
  final VoidCallback onForgotCipher;
  final VoidCallback? onGuest;
  final String? initialEmail;

  const LoginStep({
    super.key,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onCreateAccount,
    required this.onForgotCipher,
    this.onGuest,
    this.initialEmail,
  });

  @override
  State<LoginStep> createState() => _LoginStepState();
}

class _LoginStepState extends State<LoginStep> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _obscure = true;
  bool _trust = true;

  static final RegExp _emailPattern = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailValid => _emailPattern.hasMatch(_email.text.trim());

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.onSubmit(
      email: _email.text.trim(),
      password: _password.text,
      trustTerminal: _trust,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: LedgerWidgets.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 26),
            _hero(),
            const SizedBox(height: 34),
            _emailLabel(),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('login_email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: LedgerColors.ink, fontSize: 15),
              decoration: LedgerWidgets.inputDecoration(
                label: 'TERMINAL ID / EMAIL',
                prefix: const Icon(Icons.alternate_email,
                    color: LedgerColors.mint, size: 18),
                suffix: _emailValid
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.verified,
                            color: LedgerColors.success, size: 19),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'MASTER CIPHER',
              style: TextStyle(
                color: LedgerColors.mutedAlt,
                fontSize: 11,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('login_password'),
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(color: LedgerColors.ink, fontSize: 15),
              decoration: LedgerWidgets.inputDecoration(
                label: 'MASTER CIPHER',
                prefix: const Icon(Icons.lock_outline,
                    color: LedgerColors.mint, size: 18),
                suffix: IconButton(
                  key: const ValueKey('login_reveal'),
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: LedgerColors.muted,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _trust,
                    onChanged: (value) => setState(() => _trust = value ?? false),
                    activeColor: LedgerColors.mint,
                    checkColor: LedgerColors.onMint,
                    side: const BorderSide(color: LedgerColors.borderBright),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Trust this terminal (30 days)',
                    style: TextStyle(color: LedgerColors.mutedAlt, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: widget.onForgotCipher,
                  child: const Text(
                    'Forgot Cipher?',
                    style: TextStyle(color: LedgerColors.mint, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.error!,
                style: const TextStyle(color: LedgerColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('login_submit'),
              onPressed: widget.loading ? null : _submit,
              style: LedgerWidgets.mintButton(),
              child: widget.loading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LedgerColors.onMint,
                      ),
                    )
                  : const Text('Sign In to TradeLog →'),
            ),
            const SizedBox(height: 22),
            Center(
              child: GestureDetector(
                key: const ValueKey('login_create_account'),
                onTap: widget.onCreateAccount,
                child: RichText(
                  text: const TextSpan(
                    text: 'New to TradeLog? ',
                    style: TextStyle(color: LedgerColors.muted, fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Create Account →',
                        style: TextStyle(
                          color: LedgerColors.mint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            LedgerWidgets.securityFootnote(),
            if (widget.onGuest != null) ...[
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: widget.onGuest,
                  child: const Text(
                    'Continue as guest',
                    style: TextStyle(color: LedgerColors.muted, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emailLabel() {
    return Row(
      children: const [
        Text(
          'TERMINAL ID / EMAIL',
          style: TextStyle(
            color: LedgerColors.mutedAlt,
            fontSize: 11,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        Spacer(),
        _StatusTag(label: 'AUTHORIZED ONLY'),
      ],
    );
  }

  Widget _hero() {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: LedgerWidgets.glowBadge(),
          alignment: Alignment.center,
          child: const Icon(Icons.lock_outline_rounded,
              color: LedgerColors.mint, size: 30),
        ),
        const SizedBox(height: 20),
        const Text(
          'Welcome Back, Trader',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LedgerColors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Access your execution telemetry and automated journal.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LedgerColors.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;

  const _StatusTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LedgerColors.mint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LedgerColors.mint.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: LedgerColors.mint,
          fontSize: 9,
          letterSpacing: 0.8,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
