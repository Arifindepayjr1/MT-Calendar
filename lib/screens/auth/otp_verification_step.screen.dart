import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trader_log/theme/ledger_theme.dart';

/// Screen 3 — "OTP Verification" (Security Handshake).
class OtpVerificationStep extends StatefulWidget {
  final String email;
  final String? devCode;
  final bool loading;
  final String? error;
  final Future<void> Function(String code) onVerify;
  final Future<void> Function() onResend;
  final VoidCallback onEditEmail;

  const OtpVerificationStep({
    super.key,
    required this.email,
    required this.devCode,
    required this.loading,
    required this.error,
    required this.onVerify,
    required this.onResend,
    required this.onEditEmail,
  });

  @override
  State<OtpVerificationStep> createState() => _OtpVerificationStepState();
}

class _OtpVerificationStepState extends State<OtpVerificationStep> {
  final List<String> _digits = List<String>.filled(6, '');
  Timer? _timer;
  int _seconds = 46;
  String? _pasteCandidate;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds = _seconds > 0 ? _seconds - 1 : 0);
      if (_seconds == 0) _timer?.cancel();
    });
    _detectClipboardCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _detectClipboardCode() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final candidate = data?.text?.trim() ?? '';
      if (RegExp(r'^\d{6}$').hasMatch(candidate) && mounted) {
        setState(() => _pasteCandidate = candidate);
      }
    } catch (_) {
      // Clipboard access is unavailable in some embedded/test environments.
    }
  }

  void _press(String key) {
    if (key == 'backspace') {
      final last = _digits.lastIndexWhere((digit) => digit.isNotEmpty);
      if (last >= 0) setState(() => _digits[last] = '');
      return;
    }
    if (!RegExp(r'^\d$').hasMatch(key)) return;
    final index = _digits.indexWhere((digit) => digit.isEmpty);
    if (index < 0) return;
    setState(() {
      _digits[index] = key;
      _localError = null;
    });
  }

  void _paste(String code) {
    setState(() {
      for (var i = 0; i < 6; i++) {
        _digits[i] = i < code.length ? code[i] : '';
      }
      _localError = null;
    });
  }

  Future<void> _resend() async {
    await widget.onResend();
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < 6; i++) {
        _digits[i] = '';
      }
      _seconds = 46;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds = _seconds > 0 ? _seconds - 1 : 0);
        if (_seconds == 0) _timer?.cancel();
      });
    });
  }

  Future<void> _verify() async {
    final code = _digits.join();
    if (code.length != 6) {
      setState(() => _localError = 'Enter all 6 digits to verify the session.');
      return;
    }
    setState(() => _localError = null);
    await widget.onVerify(code);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final label = event.logicalKey.keyLabel;
          if (label.length == 1 && RegExp(r'\d').hasMatch(label)) {
            _press(label);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            _press('backspace');
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SingleChildScrollView(
          padding: LedgerWidgets.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              _header(),
              const SizedBox(height: 20),
              _destinationChip(),
              if (widget.devCode != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('otp_dev_code'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: LedgerColors.mint.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: LedgerColors.mint.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Local dev code: ${widget.devCode}',
                    style: const TextStyle(
                      color: LedgerColors.mint,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _pinRow(),
              if (_pasteCandidate != null) ...[
                const SizedBox(height: 12),
                _pasteChip(),
              ],
              const SizedBox(height: 12),
              _timerRow(),
              const SizedBox(height: 16),
              _tokenBanner(),
              const SizedBox(height: 18),
              _keypad(),
              if (_localError != null || widget.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _localError ?? widget.error!,
                  style: const TextStyle(color: LedgerColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('otp_submit'),
                onPressed: widget.loading ? null : _verify,
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
                    : const Text('Verify & Launch TradeLog →'),
              ),
              const SizedBox(height: 20),
              LedgerWidgets.securityFootnote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: LedgerWidgets.glowBadge(),
          alignment: Alignment.center,
          child: const Icon(Icons.shield_outlined,
              color: LedgerColors.mint, size: 30),
        ),
        const SizedBox(height: 16),
        const Text(
          'Verify Code',
          style: TextStyle(
            color: LedgerColors.white,
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'We sent a 6-digit verification code to your authorized terminal email',
          textAlign: TextAlign.center,
          style: TextStyle(color: LedgerColors.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _destinationChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: LedgerWidgets.card(color: LedgerColors.surfaceLow),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: LedgerColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: LedgerColors.success,
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LedgerColors.ink,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('otp_edit_email'),
            onPressed: widget.onEditEmail,
            icon: const Icon(Icons.edit_outlined,
                color: LedgerColors.mint, size: 17),
            tooltip: 'Edit email',
          ),
        ],
      ),
    );
  }

  Widget _pinRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 6; i++) _pinSlot(i),
      ],
    );
  }

  Widget _pinSlot(int index) {
    final value = _digits[index];
    final active = value.isEmpty && index == _digits.indexWhere((d) => d.isEmpty);
    return Container(
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LedgerColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active ? LedgerColors.mint : LedgerColors.borderBright,
          width: active ? 1.6 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: LedgerColors.mint.withValues(alpha: 0.18),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: value.isNotEmpty
          ? Text(
              value,
              style: const TextStyle(
                color: LedgerColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            )
          : active
              ? Container(
                  width: 2,
                  height: 24,
                  color: LedgerColors.mint,
                )
              : const SizedBox.shrink(),
    );
  }

  Widget _pasteChip() {
    return GestureDetector(
      onTap: () => _paste(_pasteCandidate!),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: LedgerColors.mint.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: LedgerColors.mint.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.content_paste_rounded,
                size: 16, color: LedgerColors.mint),
            const SizedBox(width: 8),
            Text(
              'Paste detected: $_pasteCandidate',
              style: const TextStyle(
                color: LedgerColors.mint,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            const Text(
              'Tap to fill',
              style: TextStyle(color: LedgerColors.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            value: _seconds / 46,
            strokeWidth: 2,
            color: LedgerColors.mint,
            backgroundColor: LedgerColors.surfaceHigh,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Resend in ${_formatSeconds(_seconds)}s',
          style: const TextStyle(
            color: LedgerColors.mutedAlt,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        const Text('•', style: TextStyle(color: LedgerColors.muted)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _resend,
          child: const Text(
            'Resend SMS',
            style: TextStyle(
              color: LedgerColors.mint,
              fontSize: 11,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tokenBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: LedgerWidgets.card(color: LedgerColors.surfaceLow),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: LedgerColors.mint, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institutional Session Token',
                  style: TextStyle(
                    color: LedgerColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Single-use PIN expires in 10 minutes',
                  style: TextStyle(color: LedgerColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _keypad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['biometric', '0', 'backspace'],
    ];
    return Column(
      children: [
        for (final row in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final key in row) _keypadButton(key),
              ],
            ),
          ),
      ],
    );
  }

  Widget _keypadButton(String key) {
    IconData icon;
    if (key == 'biometric') {
      icon = Icons.fingerprint;
    } else if (key == 'backspace') {
      icon = Icons.backspace_outlined;
    } else {
      icon = Icons.map; // unused for numeric keys
    }
    return SizedBox(
      width: 68,
      height: 50,
      child: OutlinedButton(
        key: ValueKey('otp_key_$key'),
        onPressed: () => _press(key),
        style: OutlinedButton.styleFrom(
          backgroundColor: LedgerColors.surfaceLow,
          side: const BorderSide(color: LedgerColors.borderBright),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          padding: EdgeInsets.zero,
        ),
        child: key == 'biometric' || key == 'backspace'
            ? Icon(icon, color: LedgerColors.mint, size: 20)
            : Text(
                key,
                style: const TextStyle(
                  color: LedgerColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }
}
