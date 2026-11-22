import 'package:flutter/material.dart';
import 'package:trader_log/model/auth.model.dart';
import 'package:trader_log/screens/auth/create_account_step.screen.dart';
import 'package:trader_log/screens/auth/login_step.screen.dart';
import 'package:trader_log/screens/auth/otp_verification_step.screen.dart';
import 'package:trader_log/services/auth_api_service.dart';
import 'package:trader_log/services/auth_store.dart';
import 'package:trader_log/theme/ledger_theme.dart';

enum AuthStep { login, createAccount, otp }

/// Coordinates the three-screen Disciplined Ledger authentication suite and
/// keeps the existing JWT backend as the source of truth.
class AuthScreen extends StatefulWidget {
  final AuthApiService api;
  final AuthStore store;
  final AuthStep initialStep;
  final VoidCallback? onCompleted;
  final VoidCallback? onGuest;

  const AuthScreen({
    super.key,
    required this.api,
    required this.store,
    this.initialStep = AuthStep.login,
    this.onCompleted,
    this.onGuest,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthStep _step;
  AuthRegistrationDetails? _details;
  String? _devCode;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
  }

  void _goTo(AuthStep step) {
    setState(() {
      _step = step;
      _error = null;
    });
  }

  void _back() {
    if (_step == AuthStep.otp) {
      _goTo(AuthStep.createAccount);
    } else if (_step == AuthStep.createAccount) {
      _goTo(AuthStep.login);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    } else if (widget.onGuest != null) {
      widget.onGuest!();
    }
  }

  Future<void> _signIn({
    required String email,
    required String password,
    required bool trustTerminal,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your terminal ID and master cipher.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.api.signIn(
        email: email,
        password: password,
      );
      await widget.store.saveSession(session, remember: trustTerminal);
      _finish();
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestCode(AuthRegistrationDetails details) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await widget.api.requestCode(
        email: details.email,
        password: details.password,
        name: details.name,
        framework: details.framework,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _devCode = request.devCode;
        _step = AuthStep.otp;
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final details = _details;
    if (details == null) return;
    setState(() => _error = null);
    try {
      final request = await widget.api.requestCode(
        email: details.email,
        password: details.password,
        name: details.name,
        framework: details.framework,
      );
      if (!mounted) return;
      setState(() => _devCode = request.devCode);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _verify(String code) async {
    final details = _details;
    if (details == null) {
      setState(() => _error = 'Restart registration to request a new code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.api.verifyCode(
        email: details.email,
        code: code,
      );
      await widget.store.saveSession(session);
      _finish();
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _finish() {
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _forgotCipher() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LedgerColors.surface,
        title: const Text(
          'Recover your cipher',
          style: TextStyle(color: LedgerColors.ink, fontSize: 16),
        ),
        content: const Text(
          'Enter the master cipher you used when you created the account. '
          'If you have not registered yet, create a new trader account.',
          style: TextStyle(color: LedgerColors.mutedAlt, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _goTo(AuthStep.createAccount);
            },
            style: LedgerWidgets.mintButton(height: 38),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final IconData mark;
    switch (_step) {
      case AuthStep.login:
        title = 'Log In';
        mark = Icons.show_chart_rounded;
        break;
      case AuthStep.createAccount:
        title = 'Create Account';
        mark = Icons.person_add_alt_1_outlined;
        break;
      case AuthStep.otp:
        title = 'Otp Verification';
        mark = Icons.bolt_rounded;
        break;
    }

    return Scaffold(
      backgroundColor: LedgerColors.background,
      appBar: LedgerWidgets.appBar(
        title: title,
        mark: mark,
        onBack: _back,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: switch (_step) {
          AuthStep.login => LoginStep(
              key: const ValueKey('login'),
              loading: _loading,
              error: _error,
              initialEmail: _details?.email,
              onSubmit: _signIn,
              onCreateAccount: () => _goTo(AuthStep.createAccount),
              onForgotCipher: _forgotCipher,
              onGuest: widget.onGuest,
            ),
          AuthStep.createAccount => CreateAccountStep(
              key: const ValueKey('create'),
              loading: _loading,
              error: _error,
              initialDetails: _details,
              onSubmit: _requestCode,
              onSignIn: () => _goTo(AuthStep.login),
            ),
          AuthStep.otp => OtpVerificationStep(
              key: const ValueKey('otp'),
              email: _details?.email ?? '',
              devCode: _devCode,
              loading: _loading,
              error: _error,
              onVerify: _verify,
              onResend: _resend,
              onEditEmail: () => _goTo(AuthStep.createAccount),
            ),
        },
      ),
    );
  }
}
