import 'dart:ui';
import 'package:flutter/material.dart';

class NetPnlCard extends StatefulWidget {
  final double netPnl;
  final String trendSubtitle;
  final String currency;
  final bool showInUsdForCent;

  const NetPnlCard({
    super.key,
    required this.netPnl,
    this.trendSubtitle = '+12.4% this month',
    this.currency = 'USD',
    this.showInUsdForCent = false,
  });

  @override
  State<NetPnlCard> createState() => _NetPnlCardState();
}

class _NetPnlCardState extends State<NetPnlCard> {
  bool _isHovered = false;

  bool get _isCentAccount => widget.currency.toUpperCase() == 'USC';

  String get _activeCurrency =>
      (_isCentAccount && !widget.showInUsdForCent) ? 'USC' : 'USD';

  double _scale(double raw) =>
      (_isCentAccount && widget.showInUsdForCent) ? raw / 100.0 : raw;

  String _formatCurrency(double rawVal) {
    final val = _scale(rawVal);
    final isPositive = val >= 0;
    final absVal = val.abs();
    final parts = absVal.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    if (_activeCurrency == 'USC') {
      return '${isPositive ? "+" : "-"}$intPart.${parts[1]} USC';
    }
    return '${isPositive ? "+" : "-"}\$$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isProfit = widget.netPnl >= 0;
    final valueColor = isProfit
        ? const Color(0xFFB7F7C4)
        : const Color(0xFFFF7C7C);

    final usdEquiv = (widget.netPnl / 100.0).toStringAsFixed(2);
    final tooltipText = _isCentAccount
        ? 'Net Realized P&L (${_activeCurrency}): ${_formatCurrency(widget.netPnl)} '
              '(≈ \$${usdEquiv} USD). ${widget.trendSubtitle}.'
        : 'Net Realized P&L (USD): Total profit/loss including MT5 commissions and swap fees (${widget.trendSubtitle}).';

    return Tooltip(
      message: tooltipText,
      preferBelow: true,
      waitDuration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101310),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: valueColor.withValues(alpha: 0.5)),
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
                  ? valueColor.withValues(alpha: 0.6)
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
                  Row(
                    children: [
                      Text(
                        'Net P&L ($_activeCurrency)',
                        style: const TextStyle(
                          color: Color(0xFF858D86),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
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
                    child: Icon(
                      Icons.payments_outlined,
                      color: valueColor,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatCurrency(widget.netPnl),
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.trendSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
