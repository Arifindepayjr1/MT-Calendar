import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trader_log/model/trade.model.dart';

const String tradeImportStorageKey = 'traderlog_import_v1';

/// The parsed result of an uploaded MT5 HTML report.
///
/// Kept separate from authentication so a signed-in trader, a guest and a
/// restarted app all see the same imported report on this device.
class ImportedAccount {
  final List<Trade> trades;
  final String accountName;
  final String brokerAndNumber;
  final String currency;
  final String syncSubtitle;
  final double initialDeposit;
  final double? finalBalance;

  const ImportedAccount({
    required this.trades,
    required this.accountName,
    required this.brokerAndNumber,
    required this.currency,
    this.syncSubtitle = 'Imported MT5 report · Saved on this device',
    required this.initialDeposit,
    this.finalBalance,
  });

  factory ImportedAccount.fromJson(Map<String, dynamic> json) {
    return ImportedAccount(
      trades: ((json['trades'] as List?) ?? const [])
          .map((entry) => Trade.fromJson((entry as Map).cast<String, dynamic>()))
          .toList(),
      accountName: json['accountName'] as String? ?? 'Imported Account',
      brokerAndNumber: json['brokerAndNumber'] as String? ?? 'MT5 Account',
      currency: json['currency'] as String? ?? 'USD',
      syncSubtitle: json['syncSubtitle'] as String? ??
          'Imported MT5 report · Saved on this device',
      initialDeposit: (json['initialDeposit'] as num?)?.toDouble() ?? 0.0,
      finalBalance: (json['finalBalance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'trades': trades.map((trade) => trade.toJson()).toList(),
        'accountName': accountName,
        'brokerAndNumber': brokerAndNumber,
        'currency': currency,
        'syncSubtitle': syncSubtitle,
        'initialDeposit': initialDeposit,
        'finalBalance': finalBalance,
      };
}

/// Persists the imported MT5 report locally.
///
/// Signing in or out never touches this store: the Excel/HTML report belongs to
/// the device session, so logging in cannot wipe it.
class TradeImportStore extends ChangeNotifier {
  final SharedPreferences? preferences;
  final bool persist;

  TradeImportStore({this.preferences, this.persist = true});

  factory TradeImportStore.inMemory() => TradeImportStore(persist: false);

  ImportedAccount? _data;
  bool _initialized = false;

  ImportedAccount? get data => _data;
  bool get hasImport => _data != null && _data!.trades.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!persist) return;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(tradeImportStorageKey);
      if (raw != null && raw.isNotEmpty) {
        _data = ImportedAccount.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // A corrupt or unavailable store must never block the app.
      _data = null;
    }
    notifyListeners();
  }

  Future<void> save(ImportedAccount data) async {
    _data = data;
    notifyListeners();
    if (!persist) return;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.setString(tradeImportStorageKey, jsonEncode(data.toJson()));
    } catch (_) {
      // The in-memory import still works for the current session.
    }
  }

  Future<void> clear() async {
    _data = null;
    notifyListeners();
    if (!persist) return;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.remove(tradeImportStorageKey);
    } catch (_) {
      // Ignore storage failures.
    }
  }
}
