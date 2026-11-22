import 'package:flutter/material.dart';
import 'package:trader_log/services/auth_api_service.dart';
import 'package:trader_log/services/auth_store.dart';

const _bg = Color(0xFF111411);
const _surface = Color(0xFF1A1F1B);
const _mint = Color(0xFFB7F7C4);
const _coral = Color(0xFFFF7C7C);
const _muted = Color(0xFF858D86);
const _border = Color(0xFF303832);
const _ink = Color(0xFFE8ECE8);

/// Sign in / sign up against the backend JWT endpoints.
class AuthScreen extends StatefulWidget {
  final AuthApiService api;
  final AuthStore store;

  const AuthScreen({
    super.key,
    required this.api,
    required this.store,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signUp = false;
  bool _loading = false;
  String? _error;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();
    if (email.isEmpty || password.isEmpty || (_signUp && name.isEmpty)) {
      setState(() => _error = 'Enter email, password${_signUp ? ' and name' : ''}.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = _signUp
          ? await widget.api.signUp(
              email: email,
              password: password,
              name: name,
            )
          : await widget.api.signIn(email: email, password: password);
      await widget.store.saveSession(session);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _signUp ? 'Create account' : 'Sign in',
          style: const TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TradeLog uses a JWT from the backend to save your playbook drafts.',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 18),
              _modeToggle(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_signUp) ...[
                      _field(label: 'Name', controller: _name, icon: Icons.person_outline),
                      const SizedBox(height: 14),
                    ],
                    _field(
                      label: 'Email',
                      controller: _email,
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      label: 'Password',
                      controller: _password,
                      icon: Icons.lock_outline,
                      obscure: true,
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: _coral, fontSize: 13),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint,
                    foregroundColor: const Color(0xFF111411),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF111411),
                          ),
                        )
                      : Text(
                          _signUp ? 'Create account' : 'Sign in',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _modeButton(label: 'Sign in', selected: !_signUp),
          _modeButton(label: 'Sign up', selected: _signUp),
        ],
      ),
    );
  }

  Widget _modeButton({required String label, required bool selected}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _signUp = label == 'Sign up';
          _error = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _mint : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _bg : _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: _ink, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted, fontSize: 13),
        prefixIcon: Icon(icon, color: _muted, size: 18),
        filled: true,
        fillColor: const Color(0xFF121813),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _mint),
        ),
      ),
    );
  }
}
