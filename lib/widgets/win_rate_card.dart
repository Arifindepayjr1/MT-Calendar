import 'dart:ui';
import 'package:flutter/material.dart';

class WinRateCard extends StatefulWidget {
  final double winRatePercent;
  final String contextBadgeText;

  const WinRateCard({
    super.key,
    required this.winRatePercent,
    this.contextBadgeText = '+4.2% vs benchmark',
  });

  @override
  State<WinRateCard> createState() => _WinRateCardState();
}

class _WinRateCardState extends State<WinRateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final progress = (widget.winRatePercent.clamp(0.0, 100.0)) / 100.0;

    return Tooltip(
      message:
          'Win Rate & TP/SL Hits: Percentage of winning trades out of total closed trades (${widget.contextBadgeText}).',
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
                        'Win Rate',
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
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: const Color(0xFF303832),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFB7F7C4),
                          ),
                        ),
                        const Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 11,
                          color: Color(0xFFB7F7C4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.winRatePercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFFE8ECE8),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFB7F7C4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.contextBadgeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB7F7C4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
