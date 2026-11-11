enum TradeType { buy, sell }

enum TradeOutcome { win, loss, breakeven }

enum CloseReason { takeProfit, stopLoss, manual, stopOut, other, unknown }

class Trade {
  final String id;
  final String ticket;
  final String positionId;
  final String symbol;
  final TradeType type;
  final double volume;
  final double openPrice;
  final double closePrice;
  double? stoploss;
  double? takeProfit;
  final DateTime openTime;
  final DateTime closeTime;
  final double profit;
  final double commission;
  final double swap;
  final double fee;
  final double netProfit;
  final CloseReason closeReason;
  final DateTime createdAt;

  final String accountId;

  Trade({
    required this.id,
    required this.ticket,
    required this.positionId,
    required this.symbol,
    required this.type,
    required this.volume,
    required this.openPrice,
    required this.closePrice,
    this.stoploss,
    this.takeProfit,
    required this.openTime,
    required this.closeTime,
    required this.profit,
    required this.commission,
    required this.swap,
    required this.fee,
    required this.netProfit,
    required this.closeReason,
    required this.createdAt,
    required this.accountId,
  });

  TradeOutcome get outcome {
    if (netProfit > 0) return TradeOutcome.win;
    if (netProfit < 0) return TradeOutcome.loss;
    return TradeOutcome.breakeven;
  }

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      id: json['id'] as String,
      ticket: json['ticket'] as String,
      positionId: json['positionId'] as String,
      symbol: json['symbol'] as String,
      type: TradeType.values.byName(json['type'] as String),
      volume: (json['volume'] as num).toDouble(),
      openPrice: (json['openPrice'] as num).toDouble(),
      closePrice: (json['closePrice'] as num).toDouble(),
      stoploss: (json['stoploss'] ?? json['stopLoss']) != null
          ? ((json['stoploss'] ?? json['stopLoss']) as num).toDouble()
          : null,
      takeProfit: json['takeProfit'] != null
          ? (json['takeProfit'] as num).toDouble()
          : null,
      openTime: DateTime.parse(json['openTime'] as String),
      closeTime: DateTime.parse(json['closeTime'] as String),
      profit: (json['profit'] as num).toDouble(),
      commission: (json['commission'] as num).toDouble(),
      swap: (json['swap'] as num).toDouble(),
      fee: (json['fee'] as num).toDouble(),
      netProfit: (json['netProfit'] as num).toDouble(),
      closeReason: CloseReason.values.byName(json['closeReason'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      accountId: json['accountId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'ticket': ticket,
      'positionId': positionId,
      'symbol': symbol,
      'type': type.name,
      'volume': volume,
      'openPrice': openPrice,
      'closePrice': closePrice,
      'stoploss': stoploss,
      'takeProfit': takeProfit,
      'openTime': openTime.toIso8601String(),
      'closeTime': closeTime.toIso8601String(),
      'profit': profit,
      'commission': commission,
      'swap': swap,
      'fee': fee,
      'netProfit': netProfit,
      'closeReason': closeReason.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
