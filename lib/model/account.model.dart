class Account {
  final String id;
  final String accountNumber;
  final String name;
  final String server;
  final String currency;
  final double initialBalance;
  final DateTime createdAt;

  final String userId;
  final String brokerId;

  Account({
    required this.id,
    required this.accountNumber,
    required this.name,
    required this.server,
    required this.currency,
    required this.initialBalance,
    required this.createdAt,
    required this.userId,
    required this.brokerId,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      accountNumber: json['accountNumber'] as String,
      name: json['name'] as String,
      server: json['server'] as String,
      currency: json['currency'] as String,
      initialBalance: (json['initialBalance'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['userId'] as String,
      brokerId: json['brokerId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountNumber': accountNumber,
      'name': name,
      'server': server,
      'currency': currency,
      'initialBalance': initialBalance,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'brokerId': brokerId,
    };
  }
}
