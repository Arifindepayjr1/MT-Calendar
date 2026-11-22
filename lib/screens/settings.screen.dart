import 'package:flutter/material.dart';
import 'package:trader_log/screens/auth.screen.dart';
import 'package:trader_log/services/auth_api_service.dart';
import 'package:trader_log/services/auth_store.dart';

const _bg = Color(0xFF101310);
const _surface = Color(0xFF1A1F1B);
const _mint = Color(0xFFB7F7C4);
const _muted = Color(0xFF858D86);
const _border = Color(0xFF303832);
const _ink = Color(0xFFE8ECE8);

/// Settings tab with backend JWT session controls.
class SettingsScreen extends StatelessWidget {
  final AuthStore authStore;
  final AuthApiService authApi;
  final VoidCallback onAuthChanged;

  const SettingsScreen({
    super.key,
    required this.authStore,
    required this.authApi,
    required this.onAuthChanged,
  });

  Future<void> _openAuth(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AuthScreen(api: authApi, store: authStore),
      ),
    );
    if (result == true) onAuthChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authStore,
      builder: (context, _) {
        final user = authStore.user;
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 20,
            title: const Text(
              'Settings',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _mint.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              authStore.isSignedIn
                                  ? Icons.verified_user_outlined
                                  : Icons.person_outline,
                              color: _mint,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authStore.isSignedIn
                                      ? (user?.name ?? 'Signed in')
                                      : 'Not signed in',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  authStore.isSignedIn
                                      ? (user?.email ?? '')
                                      : 'Sign in to save playbook drafts to your account.',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => authStore.isSignedIn
                              ? authStore.clear()
                              : _openAuth(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: _mint,
                            foregroundColor: const Color(0xFF111411),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            authStore.isSignedIn ? 'Sign out' : 'Sign in / Sign up',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(Icons.cloud_outlined, color: _muted, size: 21),
                  title: Text(
                    'Backend data',
                    style: TextStyle(color: _ink, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Playbooks, rulebooks and drafts are owned by the NestJS API.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
