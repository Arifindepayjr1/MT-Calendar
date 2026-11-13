import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileGreetingHeader extends StatelessWidget {
  final String accountName;
  final String brokerAndNumber;
  final String syncSubtitle;
  final String currency;
  final bool showInUsdForCent;
  final VoidCallback? onToggleCurrencyView;
  final VoidCallback? onUploadTap;

  const ProfileGreetingHeader({
    super.key,
    required this.accountName,
    required this.brokerAndNumber,
    required this.syncSubtitle,
    this.currency = 'USD',
    this.showInUsdForCent = false,
    this.onToggleCurrencyView,
    this.onUploadTap,
  });

  /// Returns "Good morning, <name>" (uses first name if full name is very long).
  String get _greetingText {
    final cleaned = accountName.trim();
    if (cleaned.isEmpty) {
      return 'Good morning';
    }
    if (cleaned.length > 18) {
      final firstName = cleaned.split(RegExp(r'\s+')).first;
      return 'Good morning, $firstName';
    }
    return 'Good morning, $cleaned';
  }

  bool get _isCentAccount => currency.toUpperCase() == 'USC';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow label
        const Text(
          'INSTITUTIONAL EXECUTION',
          style: TextStyle(
            color: Color(0xFF858D86),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        // Greeting Title (font-weight: 600, 22px)
        Text(
          _greetingText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE8ECE8),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        // Active Broker Account Selector Pill + Currency badge
        InkWell(
          onTap: onUploadTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F1B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF303832)),
            ),
            child: Row(
              children: [
                // Green live indicator dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB7F7C4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              brokerAndNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE8ECE8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF858D86),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        syncSubtitle,
                        style: const TextStyle(
                          color: Color(0xFF858D86),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Currency badge (distinguishes USC Cent vs USD Standard)
                Tooltip(
                  message: _isCentAccount
                      ? 'Cent Account (USC): 100 USC = \$1.00 USD. Tap to toggle USC ⇄ USD view.'
                      : 'Account Currency: $currency',
                  child: InkWell(
                    onTap: _isCentAccount ? onToggleCurrencyView : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _isCentAccount
                            ? const Color(0xFFFFD166).withValues(alpha: 0.16)
                            : const Color(0xFF303832),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isCentAccount
                              ? const Color(0xFFFFD166).withValues(alpha: 0.5)
                              : const Color(0xFF303832),
                        ),
                      ),
                      child: Text(
                        _isCentAccount
                            ? (showInUsdForCent ? 'USC→USD' : 'USC · CENT')
                            : currency.toUpperCase(),
                        style: TextStyle(
                          color: _isCentAccount
                              ? const Color(0xFFFFD166)
                              : const Color(0xFFE8ECE8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Status tag: "LIVE" badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB7F7C4).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFFB7F7C4),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
