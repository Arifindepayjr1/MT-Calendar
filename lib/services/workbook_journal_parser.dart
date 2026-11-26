import 'package:excel/excel.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'workbook_journal_model.dart';

const String notInSetupList = '(Not in Setup list)';

/// Reads a Trading Journal Workbook (.xlsx) and returns ONLY its input cells.
///
/// Cached formula values are deliberately ignored: every calculated column is
/// reproduced later by [computeWorkbook].
WorkbookJournal readJournal(List<int> xlsxBytes) {
  final excel = Excel.decodeBytes(xlsxBytes);
  final tables = excel.tables;
  final setup = _requireSheet(tables, 'Setup');
  final tradeLog = _requireSheet(tables, 'Trade Log');
  final cashFlowSheet = _requireSheet(tables, 'Cash Flow');

  Sheet? calendar;
  Sheet? dashboard;
  for (final entry in tables.entries) {
    final name = entry.key.toLowerCase().trim();
    if (name == 'calendar') calendar = entry.value;
    if (name == 'dashboard') dashboard = entry.value;
  }

  double numAt(Sheet sheet, String ref, double fallback) =>
      _double(_cellValue(sheet, ref)) ?? fallback;
  int intAt(Sheet sheet, String ref, int fallback) =>
      _double(_cellValue(sheet, ref))?.round() ?? fallback;
  String? textAt(Sheet sheet, String ref) => _text(_cellValue(sheet, ref));

  final currencyRaw = (textAt(setup, 'B5') ?? 'USD').toUpperCase().trim();
  final currency = (currencyRaw == 'USC' ||
          currencyRaw == 'CNT' ||
          currencyRaw == 'CENT')
      ? 'USC'
      : 'USD';

  final now = DateTime.now();
  final settings = WorkbookSettings(
    startCapital: numAt(setup, 'B4', 1000),
    currency: currency,
    contractSize: numAt(setup, 'B7', currency == 'USC' ? 1 : 100),
    monthlyTarget: numAt(setup, 'B8', 1000),
    dailyLossLimit: numAt(setup, 'B9', 300),
    maxTradesPerDay: intAt(setup, 'B10', 5),
    calendarYear: calendar == null
        ? now.year
        : intAt(calendar, 'B4', now.year),
    calendarMonth: calendar == null
        ? now.month
        : intAt(calendar, 'D4', now.month).clamp(1, 12),
    dashboardYear: dashboard == null
        ? now.year
        : intAt(dashboard, 'L49', now.year),
    accountName: 'Trading Journal',
  );

  final strategies = <String>[];
  for (var row = 12; row <= 41; row++) {
    final value = textAt(setup, 'A$row');
    if (value == null || value.isEmpty) break;
    strategies.add(value);
  }
  final sessions = <String>[];
  for (var row = 12; row <= 16; row++) {
    final value = textAt(setup, 'B$row');
    if (value == null || value.isEmpty) break;
    sessions.add(value);
  }

  final trades = <WorkbookTrade>[];
  for (var row = 6; row <= 305; row++) {
    final date = _asDate(_cellValue(tradeLog, 'B$row'));
    if (date == null) continue;
    final directionText = (textAt(tradeLog, 'F$row') ?? 'Buy').toLowerCase();
    final direction = directionText == 'sell'
        ? WorkbookDirection.sell
        : WorkbookDirection.buy;
    final symbol = textAt(tradeLog, 'E$row') ?? 'XAUUSDc';
    trades.add(WorkbookTrade(
      date: date,
      session: textAt(tradeLog, 'D$row'),
      symbol: symbol,
      direction: direction,
      strategy: textAt(tradeLog, 'G$row'),
      lots: numAt(tradeLog, 'H$row', 0),
      entry: numAt(tradeLog, 'I$row', 0),
      stopLoss: _double(_cellValue(tradeLog, 'J$row')),
      takeProfit: _double(_cellValue(tradeLog, 'K$row')),
      exit: _double(_cellValue(tradeLog, 'L$row')),
      screenshot: textAt(tradeLog, 'V$row'),
      notes: textAt(tradeLog, 'W$row'),
    ));
  }

  final cashFlows = <WorkbookCashFlow>[];
  for (var row = 6; row <= 205; row++) {
    final date = _asDate(_cellValue(cashFlowSheet, 'A$row'));
    final typeText = textAt(cashFlowSheet, 'B$row');
    final amount = _double(_cellValue(cashFlowSheet, 'C$row'));
    if (date == null || typeText == null || amount == null) continue;
    final isWithdrawal = typeText.toLowerCase().trim() == 'withdrawal';
    if (!isWithdrawal && typeText.toLowerCase().trim() != 'deposit') {
      throw FormatException(
        'Cash Flow row $row has an unknown type: "$typeText". '
        'Use Deposit or Withdrawal.',
      );
    }
    cashFlows.add(WorkbookCashFlow(
      date: date,
      type: isWithdrawal
          ? WorkbookCashFlowType.withdrawal
          : WorkbookCashFlowType.deposit,
      amount: amount.abs(),
      note: textAt(cashFlowSheet, 'E$row'),
    ));
  }

  return WorkbookJournal(
    settings: settings,
    strategies: strategies,
    sessions: sessions,
    trades: trades,
    cashFlows: cashFlows,
  );
}

/// Parses an Exness MT5 ReportHistory HTML file.
///
/// Column positions are discovered from the header row where possible. The
/// known Exness layout (14 cells per trade row) is used as a fallback.
ExnessReportData parseExnessReport(String htmlContent) {
  final document = html_parser.parse(htmlContent);
  final rows = document.querySelectorAll('tr');
  Map<String, int>? headers;

  for (final row in rows) {
    final cells = _visibleCellTexts(row);
    if (cells.length < 10) continue;
    final mapped = <String, int>{};
    for (var i = 0; i < cells.length; i++) {
      final key = _normalizeHeader(cells[i]);
      if (key.isEmpty) continue;
      mapped.putIfAbsent('openTime', () => i);
      if (_headerAliases['symbol']!.contains(key)) mapped.putIfAbsent('symbol', () => i);
      if (_headerAliases['direction']!.contains(key)) {
        mapped.putIfAbsent('direction', () => i);
      }
      if (_headerAliases['volume']!.contains(key)) {
        mapped.putIfAbsent('volume', () => i);
      }
      if (_headerAliases['entry']!.contains(key)) mapped.putIfAbsent('entry', () => i);
      if (_headerAliases['sl']!.contains(key)) mapped.putIfAbsent('sl', () => i);
      if (_headerAliases['tp']!.contains(key)) mapped.putIfAbsent('tp', () => i);
      if (_headerAliases['exit']!.contains(key)) mapped.putIfAbsent('exit', () => i);
    }
    if (mapped.containsKey('symbol') && mapped.containsKey('direction')) {
      headers = mapped;
      break;
    }
  }

  int idx(String key, int fallback) => headers?[key] ?? fallback;
  final trades = <WorkbookTrade>[];
  for (final row in rows) {
    final cells = _visibleCellTexts(row);
    if (cells.length < 14) continue;
    final directionText = cells[idx('direction', 3)].toLowerCase().trim();
    if (directionText != 'buy' && directionText != 'sell') continue;
    final date =
        _asDate(cells[idx('openTime', 0)]) ?? DateTime(2000, 1, 1);
    final symbol = cells[idx('symbol', 2)].trim();
    if (symbol.isEmpty) continue;
    trades.add(WorkbookTrade(
      date: date,
      symbol: symbol,
      direction:
          directionText == 'buy' ? WorkbookDirection.buy : WorkbookDirection.sell,
      lots: _firstDouble(cells[idx('volume', 5)]) ?? 0.0,
      entry: _double(cells[idx('entry', 6)]) ?? 0.0,
      stopLoss: _double(cells[idx('sl', 7)]),
      takeProfit: _double(cells[idx('tp', 8)]),
      exit: _double(cells[idx('exit', 10)]),
      notes: 'Position #${cells[1].trim()}',
    ));
  }

  final cashFlows = <WorkbookCashFlow>[];
  var skippedInitialBalance = false;
  for (final row in rows) {
    final cells = _visibleCellTexts(row);
    if (cells.length < 14 || cells[3].toLowerCase().trim() != 'balance') {
      continue;
    }
    final amount = _double(cells[12].replaceAll(' ', ''));
    if (!skippedInitialBalance) {
      skippedInitialBalance = true;
      continue;
    }
    if (amount == null || amount == 0) continue;
    final date = _asDate(cells[0]) ?? DateTime(2000, 1, 1);
    cashFlows.add(WorkbookCashFlow(
      date: date,
      type: amount > 0
          ? WorkbookCashFlowType.deposit
          : WorkbookCashFlowType.withdrawal,
      amount: amount.abs(),
      note: 'Exness report: ${amount > 0 ? 'deposit' : 'withdrawal'}',
    ));
  }

  return ExnessReportData(trades: trades, cashFlows: cashFlows);
}

const Map<String, List<String>> _headerAliases = {
  'openTime': ['opentime', 'time', 'date', 'ordertime'],
  'symbol': ['symbol', 'instrument'],
  'direction': ['type', 'direction', 'side'],
  'volume': ['volume', 'lots'],
  'entry': ['openprice', 'entry', 'priceopen'],
  'sl': ['sl', 'stoploss'],
  'tp': ['tp', 'takeprofit'],
  'exit': ['closeprice', 'exit', 'price_close'],
};

String _normalizeHeader(String raw) {
  return raw
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-/.]+'), '')
      .trim();
}

List<String> _visibleCellTexts(dom.Element row) {
  return row.querySelectorAll('td, th').where((cell) {
    final cls = cell.attributes['class'] ?? '';
    final style = cell.attributes['style'] ?? '';
    return !cls.contains('hidden') &&
        !style.contains('display: none') &&
        !style.contains('display:none');
  }).map((cell) => cell.text.replaceAll('\u00a0', ' ').trim()).toList();
}

Sheet _requireSheet(Map<String, Sheet> tables, String name) {
  final key = tables.keys.firstWhere(
    (k) => k.toLowerCase().trim() == name.toLowerCase().trim(),
    orElse: () => throw FormatException(
      'The workbook is missing the "$name" sheet. '
      'Use the Trading Journal Workbook template.',
    ),
  );
  return tables[key]!;
}

Object? _cellValue(Sheet sheet, String ref) {
  final cell = sheet.cell(CellIndex.indexByString(ref));
  final value = cell.value;
  if (value == null) return null;
  if (value is FormulaCellValue) return null;
  if (value is TextCellValue) return value.value.toString();
  if (value is IntCellValue) return value.value;
  if (value is DoubleCellValue) return value.value;
  if (value is DateCellValue) return value.asDateTimeLocal();
  if (value is DateTimeCellValue) return value.asDateTimeLocal();
  if (value is BoolCellValue) return value.value;
  if (value is TimeCellValue) {
    return DateTime(1899, 12, 30, value.hour, value.minute, value.second);
  }
  return value.toString();
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _double(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final cleaned = value
      .toString()
      .replaceAll('\u00a0', ' ')
      .replaceAll(' ', '')
      .replaceAll(',', '')
      .replaceAll(RegExp(r'[A-Za-z$£€]'), '')
      .trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

double? _firstDouble(Object? value) {
  if (value == null) return null;
  final first = value.toString().split('/').first;
  return _double(first);
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is num) {
    final millis = ((value.toDouble() - 25569) * 86400000).round();
    final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    return DateTime(dt.year, dt.month, dt.day);
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final iso = DateTime.tryParse(raw);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  final dotted = RegExp(r'^(\d{4})\.(\d{1,2})\.(\d{1,2})').firstMatch(raw);
  if (dotted != null) {
    return DateTime(
      int.parse(dotted.group(1)!),
      int.parse(dotted.group(2)!),
      int.parse(dotted.group(3)!),
    );
  }
  final slash = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})').firstMatch(raw);
  if (slash != null) {
    return DateTime(
      int.parse(slash.group(3)!),
      int.parse(slash.group(1)!),
      int.parse(slash.group(2)!),
    );
  }
  final named =
      RegExp(r'^(\d{1,2})[\s\-]+([A-Za-z]{3,9})[\s\-]+(\d{4})$').firstMatch(raw);
  if (named != null) {
    final month = _monthNumber(named.group(2)!);
    if (month != null) {
      return DateTime(
        int.parse(named.group(3)!),
        month,
        int.parse(named.group(1)!),
      );
    }
  }
  final namedFirst =
      RegExp(r'^([A-Za-z]{3,9})[\s\-]+(\d{1,2}),?[\s\-]+(\d{4})$')
          .firstMatch(raw);
  if (namedFirst != null) {
    final month = _monthNumber(namedFirst.group(1)!);
    if (month != null) {
      return DateTime(
        int.parse(namedFirst.group(3)!),
        month,
        int.parse(namedFirst.group(2)!),
      );
    }
  }
  return null;
}

int? _monthNumber(String raw) {
  const months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];
  final key = raw.toLowerCase().substring(0, 3);
  final index = months.indexOf(key);
  return index < 0 ? null : index + 1;
}
