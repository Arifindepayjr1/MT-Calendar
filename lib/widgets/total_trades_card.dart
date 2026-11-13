import 'dart:ui';
import 'package:flutter/material.dart';

class TotalTradesCard extends StatefulWidget {
  final int totalTrades;
  final int wins;
  final int losses;

  const TotalTradesCard({
    super.key,
    required this.totalTrades,
    required this.wins,
    required this.losses,
  });

  @override
  State<TotalTradesCard> createState() => _TotalTradesCardState();
}

class _TotalTradesCardState extends State<TotalTradesCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Total Trades: Total number of completed MT5 positions (${widget.wins} winning positions vs ${widget.losses} losing positions).',
      preferBelow: true,
      waitDuration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101310),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB7F7C4).withValues(alpha: 0.5)),
      ),
      textStyle: const TextStyle(
        color: Color(0xFFE8ECE8),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.help,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F1B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFFB7F7C4).withValues(alpha: 0.6)
                  : const Color(0xFF303832),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Total Trades',
                        style: TextStyle(
                          color: Color(0xFF858D86),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF858D86),
                        size: 13,
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101310),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF303832)),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Color(0xFFB7F7C4),
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.totalTrades}',
                style: const TextStyle(
                  color: Color(0xFFE8ECE8),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(
                      text: '${widget.wins}W',
                      style: const TextStyle(color: Color(0xFFB7F7C4)),
                    ),
                    const TextSpan(
                      text: ' / ',
                      style: TextStyle(color: Color(0xFF858D86)),
                    ),
                    TextSpan(
                      text: '${widget.losses}L',
                      style: const TextStyle(color: Color(0xFFFF7C7C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
