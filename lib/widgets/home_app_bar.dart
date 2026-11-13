import 'dart:ui';
import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String accountName;
  final VoidCallback? onUploadTap;

  const HomeAppBar({
    super.key,
    required this.accountName,
    this.onUploadTap,
  });

  String get _avatarInitial {
    final trimmed = accountName.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed[0].toUpperCase();
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF101310),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          // Minimal vector line-chart logo in #B7F7C4
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F1B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF303832)),
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              color: Color(0xFFB7F7C4),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'TradeLog',
            style: TextStyle(
              color: Color(0xFFE8ECE8),
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          // Subtle muted green pill badge "PRO"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFB7F7C4).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFB7F7C4).withValues(alpha: 0.35),
              ),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                color: Color(0xFFB7F7C4),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (onUploadTap != null)
          IconButton(
            tooltip: 'Import MT5 HTML Report',
            onPressed: onUploadTap,
            icon: const Icon(
              Icons.upload_file_rounded,
              color: Color(0xFFB7F7C4),
              size: 22,
            ),
          ),
        IconButton(
          onPressed: () {},
          splashRadius: 20,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFFE8ECE8),
            size: 22,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F1B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF303832), width: 1.2),
            ),
            child: Text(
              _avatarInitial,
              style: const TextStyle(
                color: Color(0xFFE8ECE8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
