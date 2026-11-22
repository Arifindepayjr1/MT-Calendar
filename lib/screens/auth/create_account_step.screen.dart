import 'package:flutter/material.dart';
import 'package:trader_log/model/auth.model.dart';
import 'package:trader_log/theme/ledger_theme.dart';

const List<String> tradingFrameworks = [
  'ICT / SMC',
  'Price Action',
  'Order Flow (DOM)',
  'Scalp Execution',
];

/// Screen 2 — "Create Account" (Trader Profile Onboarding).
class CreateAccountStep extends StatefulWidget {
  final bool loading;
  final String? error;
  final AuthRegistrationDetails? initialDetails;
  final Future<void> Function(AuthRegistrationDetails details) onSubmit;
  final VoidCallback onSignIn;

  const CreateAccountStep({
    super.key,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onSignIn,
    this.initialDetails,
  });

  @override
  State<CreateAccountStep> createState() => _CreateAccountStepState();
}

class _CreateAccountStepState extends State<CreateAccountStep> {
  late final TextEditingController _handle;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late String _framework;
  bool _obscure = true;
  bool _agreed = true;
  String? _localError;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDetails;
    _handle = TextEditingController(text: initial?.name ?? '');
    _email = TextEditingController(text: initial?.email ?? '');
    _password = TextEditingController(text: initial?.password ?? '');
    _framework = (initial != null && tradingFrameworks.contains(initial.framework))
        ? initial.framework
        : tradingFrameworks.first;
  }

  @override
  void dispose() {
    _handle.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  int get _strength {
    final value = _password.text;
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (value.contains(RegExp(r'\d'))) score++;
    if (value.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    if (value.contains(RegExp(r'[a-z]')) && value.contains(RegExp(r'[A-Z]'))) {
      score++;
    }
    return score;
  }

  void _submit() {
    final details = AuthRegistrationDetails(
      name: _handle.text.trim(),
      email: _email.text.trim(),
      framework: _framework,
      password: _password.text,
    );
    if (details.name.isEmpty ||
        !_emailPattern.hasMatch(details.email) ||
        details.password.length < 8) {
      setState(() {
        _localError = 'Add a handle, a valid work email and an 8+ char passphrase.';
      });
      return;
    }
    if (!_agreed) {
      setState(() => _localError = 'Accept the trader journal terms to continue.');
      return;
    }
    setState(() => _localError = null);
    FocusScope.of(context).unfocus();
    widget.onSubmit(details);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: LedgerWidgets.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _progress(),
            const SizedBox(height: 22),
            const Text(
              'Create Trader Account',
              style: TextStyle(
                color: LedgerColors.white,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Start journaling with automated MT5 telemetry and clinical discipline scoring.',
              style: TextStyle(
                color: LedgerColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            _fieldLabel('TRADER HANDLE', 'Public Callout'),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('create_handle'),
              controller: _handle,
              style: const TextStyle(color: LedgerColors.ink, fontSize: 14),
              decoration: LedgerWidgets.inputDecoration(
                label: 'TRADER HANDLE',
                prefix: const Icon(Icons.badge_outlined,
                    color: LedgerColors.mint, size: 18),
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.verified_user_outlined,
                      color: LedgerColors.success, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _fieldLabel('BROKER / WORK EMAIL', 'MT5 Telemetry Sync'),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('create_email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: LedgerColors.ink, fontSize: 14),
              decoration: LedgerWidgets.inputDecoration(
                label: 'BROKER / WORK EMAIL',
                prefix: const Icon(Icons.alternate_email,
                    color: LedgerColors.mint, size: 18),
                suffix: _emailPattern.hasMatch(_email.text.trim())
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.check_circle,
                            color: LedgerColors.success, size: 18),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 18),
            _fieldLabel('PRIMARY TRADING FRAMEWORK', 'Journal Archetype'),
            const SizedBox(height: 10),
            GridView.count(
              key: const ValueKey('framework_grid'),
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 3.1,
              children: [
                for (final framework in tradingFrameworks)
                  _frameworkChip(framework),
              ],
            ),
            const SizedBox(height: 18),
            _fieldLabel('VAULT PASSPHRASE', 'Strong: 8+ chars, sym, num'),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('create_password'),
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: LedgerColors.ink, fontSize: 14),
              decoration: LedgerWidgets.inputDecoration(
                label: 'VAULT PASSPHRASE',
                prefix: const Icon(Icons.lock_outline,
                    color: LedgerColors.mint, size: 18),
                suffix: IconButton(
                  key: const ValueKey('create_reveal'),
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: LedgerColors.muted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i < _strength
                            ? LedgerColors.mint
                            : LedgerColors.surfaceHigh,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Protects journaled entries, trade receipts, and risk drawdown logs.',
              style: TextStyle(color: LedgerColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 18),
            _proCallout(),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _agreed,
                    onChanged: (value) => setState(() => _agreed = value ?? false),
                    activeColor: LedgerColors.mint,
                    checkColor: LedgerColors.onMint,
                    side: const BorderSide(color: LedgerColors.borderBright),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'I agree to the Trader Journal Terms and acknowledge high-conviction trade risk disclaimers.',
                    style: TextStyle(color: LedgerColors.mutedAlt, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
            if (_localError != null || widget.error != null) ...[
              const SizedBox(height: 8),
              Text(
                _localError ?? widget.error!,
                style: const TextStyle(color: LedgerColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('create_submit'),
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
                  : const Text('Send Verification Code →'),
            ),
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                key: const ValueKey('create_sign_in'),
                onTap: widget.onSignIn,
                child: const Text(
                  'Already journaling on TradeLog? Sign In >',
                  style: TextStyle(color: LedgerColors.mint, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, String hint) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: LedgerColors.mutedAlt,
            fontSize: 10,
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
        const Spacer(),
        Text(
          hint,
          style: const TextStyle(color: LedgerColors.muted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _frameworkChip(String framework) {
    final selected = framework == _framework;
    return GestureDetector(
      key: ValueKey('framework_$framework'),
      onTap: () => setState(() => _framework = framework),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? LedgerColors.mint.withValues(alpha: 0.10)
              : LedgerColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? LedgerColors.mint : LedgerColors.borderBright,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 15,
              color: selected ? LedgerColors.mint : LedgerColors.muted,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                framework,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? LedgerColors.ink : LedgerColors.mutedAlt,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress() {
    return Column(
      children: [
        Row(
          children: const [
            Text(
              'STEP 1 OF 2: TRADER PROFILE',
              style: TextStyle(
                color: LedgerColors.mutedAlt,
                fontSize: 10,
                letterSpacing: 0.9,
                fontFamily: 'monospace',
              ),
            ),
            Spacer(),
            Text(
              '50% Completed',
              style: TextStyle(color: LedgerColors.mint, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: LedgerColors.mint,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: LedgerColors.surface,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: LedgerColors.borderBright),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _proCallout() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: LedgerWidgets.card(color: LedgerColors.surfaceLow),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LedgerColors.mint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.bolt_rounded,
                color: LedgerColors.mint, size: 19),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Free 14-Day Pro Sync Included • Instant MT4/MT5 webhook ingestion • No credit card required.',
              style: TextStyle(
                color: LedgerColors.mutedAlt,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
