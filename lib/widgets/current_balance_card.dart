import 'dart:ui';
import 'package:flutter/material.dart';

class CurrentBalanceCard extends StatefulWidget {
  final double currentBalance;
  final double initialDeposit;
  final double netPnl;
  final String currency;
  final bool showInUsdForCent;
  final VoidCallback? onToggleCurrencyView;

  const CurrentBalanceCard({
    super.key,
    required this.currentBalance,
    required this.initialDeposit,
    required this.netPnl,
    this.currency = 'USD',
    this.showInUsdForCent = false,
    this.onToggleCurrencyView,
  });

  @override
  State<CurrentBalanceCard> createState() => _CurrentBalanceCardState();
}

class _CurrentBalanceCardState extends State<CurrentBalanceCard> {
  bool _isHovered = false;

  bool get _isCentAccount => widget.currency.toUpperCase() == 'USC';

  /// Active display currency ("USC" or "USD")
  String get _activeCurrency =>
      (_isCentAccount && !widget.showInUsdForCent) ? 'USC' : 'USD';

  /// Converts raw value if user toggled "USC -> USD" (100 USC = 1 USD)
  double _scale(double raw) =>
      (_isCentAccount && widget.showInUsdForCent) ? raw / 100.0 : raw;

  String _formatNumber(double val) {
    final absVal = val.abs();
    final parts = absVal.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }

  String _formatMoney(double rawValue, {bool showSign = false}) {
    final scaled = _scale(rawValue);
    final isNeg = scaled < 0;
    final sign = showSign ? (isNeg ? '-' : '+') : (isNeg ? '-' : '');
    final formatted = _formatNumber(scaled);

    if (_activeCurrency == 'USC') {
      return '$sign$formatted USC';
    }
    return '$sign\$$formatted';
  }

  String _formatUsdEquivalent(double rawUsc) {
    final usd = rawUsc / 100.0;
    final isNeg = usd < 0;
    return '${isNeg ? "-" : ""}\$${_formatNumber(usd)} USD';
  }

  double get _growthPercent {
    if (widget.initialDeposit <= 0) return 0.0;
    return (widget.netPnl / widget.initialDeposit) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.netPnl >= 0;
    final accentColor = isPositive
        ? const Color(0xFFB7F7C4)
        : const Color(0xFFFF7C7C);

    final tooltipMsg = _isCentAccount
        ? 'Current Balance (${_activeCurrency}): ${_formatMoney(widget.currentBalance)} '
              '(≈ ${_formatUsdEquivalent(widget.currentBalance)} at 100 USC = \$1 USD). '
              'Starting deposit: ${_formatMoney(widget.initialDeposit)} + Net P&L: ${_formatMoney(widget.netPnl, showSign: true)}.'
        : 'Current Account Balance (USD): Starting deposit (${_formatMoney(widget.initialDeposit)}) + Net Realized P&L (${_formatMoney(widget.netPnl, showSign: true)} after commission & swap).';

    return Tooltip(
      message: tooltipMsg,
      preferBelow: true,
      waitDuration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF101310),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFB7F7C4).withValues(alpha: 0.5),
        ),
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
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F1B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFFB7F7C4).withValues(alpha: 0.6)
                  : const Color(0xFF303832),
              width: _isHovered ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101310),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF303832)),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFFB7F7C4),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isCentAccount
                            ? 'CURRENT BALANCE (CENT · USC)'
                            : 'CURRENT ACCOUNT BALANCE (USD)',
                        style: const TextStyle(
                          color: Color(0xFF858D86),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_isCentAccount && widget.onToggleCurrencyView != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: widget.onToggleCurrencyView,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFD166,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFFD166,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                widget.showInUsdForCent
                                    ? 'Viewing USD ⇄'
                                    : 'USC ⇄ USD',
                                style: const TextStyle(
                                  color: Color(0xFFFFD166),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '${isPositive ? "+" : ""}${_growthPercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF858D86),
                        size: 15,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatMoney(widget.currentBalance),
                        style: const TextStyle(
                          color: Color(0xFFE8ECE8),
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  if (_isCentAccount && !widget.showInUsdForCent) ...[
                    const SizedBox(width: 10),
                    Text(
                      '≈ ${_formatUsdEquivalent(widget.currentBalance)}',
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF303832), height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Initial / Deposit: ${_formatMoney(widget.initialDeposit)}',
                    style: const TextStyle(
                      color: Color(0xFF858D86),
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      children: [
                        const TextSpan(
                          text: 'Net P&L: ',
                          style: TextStyle(color: Color(0xFF858D86)),
                        ),
                        TextSpan(
                          text: _formatMoney(widget.netPnl, showSign: true),
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
