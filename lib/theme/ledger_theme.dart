import 'package:flutter/material.dart';

/// "Disciplined Ledger" — the shared dark cyber-fintech token set used by the
/// authentication suite and the rest of the app.
abstract final class LedgerColors {
  static const Color background = Color(0xFF111411);
  static const Color surfaceLow = Color(0xFF191C19);
  static const Color surface = Color(0xFF202320);
  static const Color surfaceHigh = Color(0xFF2B2E2A);
  static const Color surfaceBright = Color(0xFF373A36);
  static const Color mint = Color(0xFFB7F7C4);
  static const Color ink = Color(0xFFF0FDF4);
  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFF889088);
  static const Color mutedAlt = Color(0xFF94A3B8);
  static const Color border = Color(0xFF252B25);
  static const Color borderBright = Color(0xFF2D352D);
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFF87171);
  static const Color onMint = Color(0xFF0C0F0C);
}

/// Small reusable pieces that keep the three auth screens visually identical.
abstract final class LedgerWidgets {
  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(20, 20, 20, 32);

  static BoxDecoration glowBadge({double size = 66}) => BoxDecoration(
        color: LedgerColors.surfaceLow,
        shape: BoxShape.circle,
        border: Border.all(color: LedgerColors.borderBright),
        boxShadow: [
          BoxShadow(
            color: LedgerColors.mint.withValues(alpha: 0.12),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      );

  static BoxDecoration card({Color color = LedgerColors.surface}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LedgerColors.borderBright),
      );

  static BoxDecoration input(bool valid) => BoxDecoration(
        color: LedgerColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: valid ? LedgerColors.success : LedgerColors.borderBright,
        ),
      );

  static ButtonStyle mintButton({double height = 52}) => FilledButton.styleFrom(
        backgroundColor: LedgerColors.mint,
        foregroundColor: LedgerColors.onMint,
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );

  static InputDecoration inputDecoration({
    required String label,
    Widget? prefix,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: LedgerColors.muted,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
        floatingLabelStyle: const TextStyle(
          color: LedgerColors.mint,
          fontSize: 12,
        ),
        filled: true,
        fillColor: LedgerColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: prefix,
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: LedgerColors.borderBright),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: LedgerColors.mint, width: 1.6),
        ),
      );

  /// Pinned app bar: optional back chevron, centred labelled title, avatar.
  /// A null [onBack] hides the chevron, so the root login step has no route
  /// back to the main navigation.
  static PreferredSizeWidget appBar({
    required String title,
    required IconData mark,
    VoidCallback? onBack,
  }) =>
      AppBar(
        backgroundColor: LedgerColors.background,
        surfaceTintColor: LedgerColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        leading: onBack == null
            ? null
            : IconButton(
                key: ValueKey('auth_back_$title'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: LedgerColors.ink, size: 19),
                onPressed: onBack,
                tooltip: 'Back',
              ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(mark, color: LedgerColors.mint, size: 17),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: LedgerColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: LedgerColors.surfaceHigh,
              child: Icon(Icons.person_outline,
                  size: 17, color: LedgerColors.muted),
            ),
          ),
        ],
      );

  static Widget securityFootnote() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_outline, size: 13, color: LedgerColors.muted),
          SizedBox(width: 6),
          Text(
            '256-bit TLS Multi-Factor Protocol',
            style: TextStyle(color: LedgerColors.muted, fontSize: 11),
          ),
        ],
      );
}
