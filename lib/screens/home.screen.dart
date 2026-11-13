import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/widgets/home_app_bar.dart';
import 'package:trader_log/widgets/profile_greeting_header.dart';
import 'package:trader_log/widgets/current_balance_card.dart';
import 'package:trader_log/widgets/total_trades_card.dart';
import 'package:trader_log/widgets/win_rate_card.dart';
import 'package:trader_log/widgets/net_pnl_card.dart';
import 'package:trader_log/widgets/avg_rr_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trade> _trades = [];
  bool _hasImported = false;
  int _visibleTradeCount = 5;

  // Default placeholder context from spec (updates when HTML report is uploaded)
  String _accountName = 'Alex';
  String _brokerAndNumber = 'IC Markets (MT5 #482910)';
  String _syncSubtitle = 'Tap to upload MT5 HTML report';

  // Account currency ('USD' or 'USC' for Cent accounts)
  String _accountCurrency = 'USD';
  // Allows user to toggle viewing a Cent account (USC) in USD (100 USC = $1 USD)
  bool _showInUsdForCent = false;

  // Balance tracking (defaults before upload, updated from HTML Deals / Summary on upload)
  double _initialDeposit = 5000.00;
  double? _extractedFinalBalance;

  /// Converts raw file bytes into a readable String (handles UTF-16LE & UTF-8).
  String _decodeBytes(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final codeUnits = <int>[];
      for (int i = 2; i + 1 < bytes.length; i += 2) {
        codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
      }
      return String.fromCharCodes(codeUnits);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Parses MT5 date string "2026.09.01 08:20:38" -> DateTime
  DateTime _parseMt5Date(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    final datePart = parts[0].replaceAll('.', '-');
    final timePart = parts.length > 1 ? parts[1] : '00:00:00';
    return DateTime.parse('${datePart}T$timePart');
  }

  /// Parses nullable double ("4415.00" -> 4415.0, "" -> null)
  double? _parseNullableDouble(String raw) {
    final cleaned = raw.replaceAll(' ', '').replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Parses volume ("0.1" or "0.1 / 0.1" -> 0.1)
  double _parseVolume(String raw) {
    final firstPart = raw.split('/').first.replaceAll(' ', '').trim();
    return double.tryParse(firstPart) ?? 0.0;
  }

  /// Filters out hidden <td class="hidden"> cells that MT5 injects into HTML rows
  List<dom.Element> _visibleCells(dom.Element row) {
    return row.querySelectorAll('td').where((td) {
      final cls = td.attributes['class'] ?? '';
      final style = td.attributes['style'] ?? '';
      return !cls.contains('hidden') &&
          !style.contains('display: none') &&
          !style.contains('display:none');
    }).toList();
  }

  /// Detects account currency ('USC' vs 'USD') from MT5 Account row or symbol suffixes
  String _detectCurrency({
    String? rawAccountValue,
    String? rawCurrencyRow,
    required List<String> symbols,
  }) {
    // 1. Explicit "Currency:" row if present
    if (rawCurrencyRow != null && rawCurrencyRow.isNotEmpty) {
      final code = rawCurrencyRow.trim().toUpperCase();
      if (code == 'USC' || code == 'CNT' || code == 'CENT') return 'USC';
      if (code.length == 3) return code;
    }

    // 2. Inside parentheses of Account row: e.g. "12345678 (USC, Exness-Real, Real)"
    if (rawAccountValue != null && rawAccountValue.isNotEmpty) {
      final match = RegExp(r'\(([A-Za-z]{3,4})\b').firstMatch(rawAccountValue);
      if (match != null) {
        final code = match.group(1)!.toUpperCase();
        if (code == 'USC' || code == 'CNT' || code == 'CENT') return 'USC';
        return code;
      }
    }

    // 3. Fallback: Check if traded symbols use Cent suffix 'c' (e.g. "XAUUSD-ECNc", "XAUUSDc")
    final nonEmptySymbols = symbols.where((s) => s.isNotEmpty).toList();
    if (nonEmptySymbols.isNotEmpty &&
        nonEmptySymbols.every((s) => s.endsWith('c') && s.length > 6)) {
      return 'USC';
    }

    return 'USD';
  }

  /// Determines whether TP or SL was hit using Deal comments (if available)
  /// or by checking if closePrice reached takeProfit / stoploss.
  CloseReason _detectCloseReason({
    required TradeType type,
    required double closePrice,
    required double? stopLoss,
    required double? takeProfit,
    String? dealComment,
  }) {
    final comment = (dealComment ?? '').toLowerCase();
    if (comment.contains('tp')) return CloseReason.takeProfit;
    if (comment.contains('sl')) return CloseReason.stopLoss;
    if (comment.contains('so')) return CloseReason.stopOut;

    if (type == TradeType.buy) {
      if (takeProfit != null && takeProfit > 0 && closePrice >= takeProfit) {
        return CloseReason.takeProfit;
      }
      if (stopLoss != null && stopLoss > 0 && closePrice <= stopLoss) {
        return CloseReason.stopLoss;
      }
    } else {
      if (takeProfit != null && takeProfit > 0 && closePrice <= takeProfit) {
        return CloseReason.takeProfit;
      }
      if (stopLoss != null && stopLoss > 0 && closePrice >= stopLoss) {
        return CloseReason.stopLoss;
      }
    }

    return CloseReason.manual;
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
      withData: true,
    );

    if (result == null || result.files.first.bytes == null) return;

    final file = result.files.first;
    final htmlContent = _decodeBytes(file.bytes!);
    final document = html_parser.parse(htmlContent);
    final rows = document.querySelectorAll('tr');

    String currentSection = '';
    String? extractedName;
    String? extractedAccount;
    String? rawAccountFullText;
    String? extractedCurrencyRow;
    String? extractedCompany;

    double depositSum = 0.0;
    double? lastDealBalance;

    final List<Map<String, dynamic>> rawPositions = [];
    final Map<String, String> dealCommentsByOrder = {};

    for (final row in rows) {
      final rowText = row.text.trim();

      // Extract Account Header & Summary Balance if present in the MT5 HTML
      final rawCells = row.querySelectorAll('td, th');
      if (rawCells.length >= 2) {
        final label = rawCells[0].text
            .replaceAll('\u00A0', ' ')
            .trim()
            .toLowerCase();
        final normalizedLabel = label.replaceAll(RegExp(r'\s+'), '');

        // Pick the first non-empty value cell after the label cell
        String value = '';
        for (int i = 1; i < rawCells.length; i++) {
          final candidate = rawCells[i].text.replaceAll('\u00A0', ' ').trim();
          if (candidate.isNotEmpty) {
            value = candidate;
            break;
          }
        }

        if (value.isNotEmpty) {
          if (normalizedLabel.startsWith('name:')) {
            extractedName = value;
          } else if (normalizedLabel.startsWith('account:')) {
            rawAccountFullText = value;
            extractedAccount = value.split(' ').first.trim();
          } else if (normalizedLabel.startsWith('currency:')) {
            extractedCurrencyRow = value;
          } else if (normalizedLabel.startsWith('company:')) {
            extractedCompany = value;
          } else if (normalizedLabel == 'balance:') {
            final parsedBal = _parseNullableDouble(value);
            if (parsedBal != null) {
              lastDealBalance = parsedBal;
            }
          }
        }
      }

      // Track which MT5 report section we are inside
      if (rowText == 'Positions') {
        currentSection = 'positions';
        continue;
      } else if (rowText == 'Orders' || rowText == 'Working Orders') {
        currentSection = 'orders';
        continue;
      } else if (rowText == 'Deals') {
        currentSection = 'deals';
        continue;
      }

      final cells = _visibleCells(row);

      // 1. Extract rows from "Positions" section
      if (currentSection == 'positions' && cells.length >= 13) {
        final typeStr = cells[3].text.trim().toLowerCase();
        if (typeStr != 'buy' && typeStr != 'sell') continue;

        rawPositions.add({
          'openTime': _parseMt5Date(cells[0].text),
          'ticket': cells[1].text.trim(),
          'symbol': cells[2].text.trim(),
          'type': typeStr == 'buy' ? TradeType.buy : TradeType.sell,
          'volume': _parseVolume(cells[4].text),
          'openPrice': _parseNullableDouble(cells[5].text) ?? 0.0,
          'stopLoss': _parseNullableDouble(cells[6].text),
          'takeProfit': _parseNullableDouble(cells[7].text),
          'closeTime': _parseMt5Date(cells[8].text),
          'closePrice': _parseNullableDouble(cells[9].text) ?? 0.0,
          'commission': _parseNullableDouble(cells[10].text) ?? 0.0,
          'swap': _parseNullableDouble(cells[11].text) ?? 0.0,
          'profit': _parseNullableDouble(cells[12].text) ?? 0.0,
        });
      }

      // 2. Check "Deals" section for [tp]/[sl] comments AND running balance / deposits
      if (currentSection == 'deals' && cells.length >= 12) {
        final dealType = cells[3].text.trim().toLowerCase();
        final direction = cells[4].text.trim().toLowerCase();

        // Track deposits/withdrawals from "balance" rows
        if (dealType == 'balance') {
          final balProfit = _parseNullableDouble(cells[10].text);
          if (balProfit != null && balProfit > 0) {
            depositSum += balProfit;
          }
        }

        // Track running Balance column (cells[11])
        final runningBal = _parseNullableDouble(cells[11].text);
        if (runningBal != null) {
          lastDealBalance = runningBal;
        }

        if (cells.length >= 13 &&
            (direction == 'out' || direction == 'in/out')) {
          final orderId = cells[7].text.trim();
          final comment = cells[12].text.trim();
          if (comment.isNotEmpty) {
            dealCommentsByOrder[orderId] = comment;
          }
        }
      }
    }

    final List<Trade> extracted = rawPositions.map((p) {
      final ticket = p['ticket'] as String;
      final type = p['type'] as TradeType;
      final closePrice = p['closePrice'] as double;
      final stopLoss = p['stopLoss'] as double?;
      final takeProfit = p['takeProfit'] as double?;
      final profit = p['profit'] as double;
      final commission = p['commission'] as double;
      final swap = p['swap'] as double;

      final reason = _detectCloseReason(
        type: type,
        closePrice: closePrice,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        dealComment: dealCommentsByOrder[ticket],
      );

      return Trade(
        id: 'trd_$ticket',
        accountId: 'acc_001',
        ticket: ticket,
        positionId: ticket,
        symbol: p['symbol'] as String,
        type: type,
        volume: p['volume'] as double,
        openPrice: p['openPrice'] as double,
        closePrice: closePrice,
        stoploss: stopLoss,
        takeProfit: takeProfit,
        openTime: p['openTime'] as DateTime,
        closeTime: p['closeTime'] as DateTime,
        profit: profit,
        commission: commission,
        swap: swap,
        fee: 0.0,
        netProfit: profit + commission + swap,
        closeReason: reason,
        createdAt: DateTime.now(),
      );
    }).toList();

    // Sort newest closed trades first for "Recent Trades"
    extracted.sort((a, b) => b.closeTime.compareTo(a.closeTime));

    final detectedCurrency = _detectCurrency(
      rawAccountValue: rawAccountFullText,
      rawCurrencyRow: extractedCurrencyRow,
      symbols: extracted.map((e) => e.symbol).toList(),
    );

    final totalNetPnl = extracted.fold(0.0, (sum, t) => sum + t.netProfit);

    setState(() {
      _trades = extracted;
      _hasImported = true;
      _visibleTradeCount = 5;
      _accountCurrency = detectedCurrency;
      _showInUsdForCent = false;

      if (extractedName != null && extractedName.isNotEmpty) {
        _accountName = extractedName;
      }
      if (extractedAccount != null && extractedAccount.isNotEmpty) {
        final broker = (extractedCompany != null && extractedCompany.isNotEmpty)
            ? extractedCompany
            : 'MT5 Account';
        _brokerAndNumber = '$broker (MT5 #$extractedAccount)';
      }

      if (depositSum > 0) {
        _initialDeposit = depositSum;
      } else if (lastDealBalance != null) {
        _initialDeposit = lastDealBalance - totalNetPnl;
      }
      _extractedFinalBalance = lastDealBalance;

      _syncSubtitle =
          'Imported ${file.name} · ${extracted.length} positions ($detectedCurrency)';
    });
  }

  // --- Currency Helpers ---
  bool get _isCentAccount => _accountCurrency.toUpperCase() == 'USC';

  String get _activeDisplayCurrency =>
      (_isCentAccount && !_showInUsdForCent) ? 'USC' : 'USD';

  double _scaleAmount(double raw) =>
      (_isCentAccount && _showInUsdForCent) ? raw / 100.0 : raw;

  String _formatAmount(double raw, {bool showSign = false}) {
    final val = _scaleAmount(raw);
    final isNeg = val < 0;
    final sign = showSign ? (isNeg ? '-' : '+') : (isNeg ? '-' : '');
    final absStr = val.abs().toStringAsFixed(2);
    if (_activeDisplayCurrency == 'USC') {
      return '$sign$absStr USC';
    }
    return '$sign\$$absStr';
  }

  void _toggleCentCurrencyView() {
    setState(() {
      _showInUsdForCent = !_showInUsdForCent;
    });
  }

  // --- Computed Metrics (Uses Spec Defaults Before Upload, Real Data After Upload) ---
  int get _totalTrades => _hasImported ? _trades.length : 42;
  int get _winCount =>
      _hasImported ? _trades.where((t) => t.netProfit > 0).length : 28;
  int get _lossCount =>
      _hasImported ? _trades.where((t) => t.netProfit < 0).length : 14;

  double get _winRatePercent {
    if (!_hasImported) return 66.7;
    final denom = _winCount + _lossCount;
    if (denom == 0) return 0.0;
    return (_winCount / denom) * 100.0;
  }

  double get _netPnl => _hasImported
      ? _trades.fold(0.0, (sum, t) => sum + t.netProfit)
      : 4820.50;

  double get _currentBalance {
    if (!_hasImported) return 9820.50;
    if (_extractedFinalBalance != null) return _extractedFinalBalance!;
    return _initialDeposit + _netPnl;
  }

  double get _grossProfit => _trades.fold(0.0, (sum, t) => sum + t.profit);

  double get _totalCosts =>
      _trades.fold(0.0, (sum, t) => sum + t.commission + t.swap);

  int get _tpHitCount =>
      _trades.where((t) => t.closeReason == CloseReason.takeProfit).length;

  int get _slHitCount =>
      _trades.where((t) => t.closeReason == CloseReason.stopLoss).length;

  int get _manualCloseCount => _trades
      .where(
        (t) =>
            t.closeReason != CloseReason.takeProfit &&
            t.closeReason != CloseReason.stopLoss,
      )
      .length;

  /// Calculates average realized R:R for trades that have a valid Stop Loss.
  double? get _avgRealizedRr {
    if (!_hasImported) return 2.14;
    final List<double> rValues = [];
    for (final t in _trades) {
      final sl = t.stoploss;
      if (sl == null || sl <= 0) continue;
      final riskDistance = (t.openPrice - sl).abs();
      if (riskDistance <= 0) continue;

      final signedMove = t.type == TradeType.buy
          ? (t.closePrice - t.openPrice)
          : (t.openPrice - t.closePrice);
      rValues.add(signedMove / riskDistance);
    }
    if (rValues.isEmpty) return null;
    final sum = rValues.fold(0.0, (a, b) => a + b);
    return sum / rValues.length;
  }

  @override
  Widget build(BuildContext context) {
    final displayedTrades = _trades
        .take(math.min(_visibleTradeCount, _trades.length))
        .toList();
    final remainingCount = _trades.length - displayedTrades.length;

    return Scaffold(
      backgroundColor: const Color(0xFF101310),
      appBar: HomeAppBar(
        accountName: _accountName,
        onUploadTap: _uploadFile,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Profile Greeting & Active Broker Context (shows USC/USD badge)
                  ProfileGreetingHeader(
                    accountName: _accountName,
                    brokerAndNumber: _brokerAndNumber,
                    syncSubtitle: _syncSubtitle,
                    currency: _accountCurrency,
                    showInUsdForCent: _showInUsdForCent,
                    onToggleCurrencyView: _toggleCentCurrencyView,
                    onUploadTap: _uploadFile,
                  ),
                  const SizedBox(height: 16),

                  // 2. Manual Upload Action Banner
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _uploadFile,
                      icon: const Icon(
                        Icons.upload_file_rounded,
                        size: 18,
                        color: Color(0xFFB7F7C4),
                      ),
                      label: Text(
                        _hasImported
                            ? 'Upload Another MT5 HTML Report'
                            : 'Upload MT5 HTML Report (Manual PoC)',
                        style: const TextStyle(
                          color: Color(0xFFB7F7C4),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1F1B),
                        side: const BorderSide(color: Color(0xFF303832)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. ONE BIG CARD: Current Account Balance (with USC/USD support & hover hint)
                  CurrentBalanceCard(
                    currentBalance: _currentBalance,
                    initialDeposit: _initialDeposit,
                    netPnl: _netPnl,
                    currency: _accountCurrency,
                    showInUsdForCent: _showInUsdForCent,
                    onToggleCurrencyView: _toggleCentCurrencyView,
                  ),
                  const SizedBox(height: 12),

                  // 4. FOUR KPI CARDS BELOW IT (with hover hints on each card)
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.38,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      TotalTradesCard(
                        totalTrades: _totalTrades,
                        wins: _winCount,
                        losses: _lossCount,
                      ),
                      WinRateCard(
                        winRatePercent: _winRatePercent,
                        contextBadgeText: _hasImported
                            ? 'TP: $_tpHitCount · SL: $_slHitCount'
                            : '+4.2% vs benchmark',
                      ),
                      NetPnlCard(
                        netPnl: _netPnl,
                        currency: _accountCurrency,
                        showInUsdForCent: _showInUsdForCent,
                        trendSubtitle: _hasImported
                            ? 'Gross: ${_formatAmount(_grossProfit)} · Fee: ${_formatAmount(_totalCosts)}'
                            : '+12.4% this month',
                      ),
                      AvgRrCard(
                        avgRr: _avgRealizedRr,
                        targetText: _hasImported
                            ? 'Manual closes: $_manualCloseCount'
                            : 'Target: 2.00 R',
                      ),
                    ],
                  ),

                  // 5. Recent Trades List (5 initial + "See More (+10)" button)
                  if (_hasImported) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Recent Trades',
                              style: TextStyle(
                                color: Color(0xFFE8ECE8),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1F1B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF303832),
                                ),
                              ),
                              child: Text(
                                '${displayedTrades.length}/${_trades.length}',
                                style: const TextStyle(
                                  color: Color(0xFFB7F7C4),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'TP: $_tpHitCount · SL: $_slHitCount · Manual: $_manualCloseCount',
                          style: const TextStyle(
                            color: Color(0xFF858D86),
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...displayedTrades.map(_buildTradeItem),

                    // "See More (+10)" button when more trades exist
                    if (remainingCount > 0) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _visibleTradeCount += 10;
                            });
                          },
                          icon: const Icon(
                            Icons.expand_more_rounded,
                            color: Color(0xFFB7F7C4),
                            size: 20,
                          ),
                          label: Text(
                            'See More (+${math.min(10, remainingCount)} more · $remainingCount left)',
                            style: const TextStyle(
                              color: Color(0xFFB7F7C4),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1F1B),
                            side: const BorderSide(color: Color(0xFF303832)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else if (_trades.length > 5) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _visibleTradeCount = 5;
                            });
                          },
                          child: const Text(
                            'Show Less (Back to 5)',
                            style: TextStyle(
                              color: Color(0xFF858D86),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeItem(Trade t) {
    final isWin = t.netProfit >= 0;
    final isTpHit = t.closeReason == CloseReason.takeProfit;
    final isSlHit = t.closeReason == CloseReason.stopLoss;

    // Green tinted background & border when TP is hit, Red when SL is hit
    final Color cardBg = isTpHit
        ? const Color(0xFFB7F7C4).withValues(alpha: 0.08)
        : isSlHit
        ? const Color(0xFFFF7C7C).withValues(alpha: 0.08)
        : const Color(0xFF1A1F1B);

    final Color borderColor = isTpHit
        ? const Color(0xFFB7F7C4).withValues(alpha: 0.45)
        : isSlHit
        ? const Color(0xFFFF7C7C).withValues(alpha: 0.45)
        : const Color(0xFF303832);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${t.symbol} · ${t.type.name.toUpperCase()} ${t.volume}L',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE8ECE8),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _closeReasonBadge(t.closeReason),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '#${t.ticket}  ·  ${t.openPrice} → ${t.closePrice}',
                  style: const TextStyle(
                    color: Color(0xFF858D86),
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'SL: ${t.stoploss ?? "—"}   TP: ${t.takeProfit ?? "—"}   Comm: ${_formatAmount(t.commission)}',
                  style: const TextStyle(
                    color: Color(0xFF858D86),
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatAmount(t.netProfit, showSign: true),
                style: TextStyle(
                  color: isWin
                      ? const Color(0xFFB7F7C4)
                      : const Color(0xFFFF7C7C),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gross: ${_formatAmount(t.profit)}',
                style: const TextStyle(
                  color: Color(0xFF858D86),
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Solid green pill when TP is hit, solid red pill when SL is hit
  Widget _closeReasonBadge(CloseReason reason) {
    String text;
    Color bg;
    Color fg;

    switch (reason) {
      case CloseReason.takeProfit:
        text = 'TP HIT';
        bg = const Color(0xFFB7F7C4);
        fg = const Color(0xFF101310);
        break;
      case CloseReason.stopLoss:
        text = 'SL HIT';
        bg = const Color(0xFFFF7C7C);
        fg = const Color(0xFF101310);
        break;
      default:
        text = 'MANUAL';
        bg = const Color(0xFF303832);
        fg = const Color(0xFFE8ECE8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
