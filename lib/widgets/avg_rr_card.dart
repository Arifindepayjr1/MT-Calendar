import 'dart:ui';
import 'package:flutter/material.dart';

class AvgRrCard extends StatefulWidget {
  final double? avgRr;
  final String targetText;

  const AvgRrCard({
    super.key,
    required this.avgRr,
    this.targetText = 'Target: 2.00 R',
  });

  @override
  State<AvgRrCard> createState() => _AvgRrCardState();
}

class _AvgRrCardState extends State<AvgRrCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.avgRr != null
        ? '${widget.avgRr!.toStringAsFixed(2)} R'
        : '— R';

    return Tooltip(
      message:
          'Avg Realized R:R: Average Risk-to-Reward multiple achieved on positions with a Stop Loss (${widget.targetText}).',
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
                        'Avg Realized R:R',
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
                      Icons.gps_fixed_rounded,
                      color: Color(0xFFB7F7C4),
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                displayValue,
                style: const TextStyle(
                  color: Color(0xFFE8ECE8),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.targetText,
                style: const TextStyle(
                  color: Color(0xFF858D86),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
