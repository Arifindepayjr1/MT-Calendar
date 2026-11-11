class Import {
  final String id;
  final String fileName;
  final DateTime importedAt;
  final int totalPositions;
  final int successfulPositions;
  final int duplicatePositions;
  final int failedPositions;
  final String accountId;

  Import({
    required this.id,
    required this.fileName,
    required this.importedAt,
    required this.totalPositions,
    required this.successfulPositions,
    required this.duplicatePositions,
    required this.failedPositions,
    required this.accountId,
  });

  factory Import.fromJson(Map<String, dynamic> json) {
    return Import(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      importedAt: DateTime.parse(json['importedAt'] as String),
      totalPositions: json['totalPositions'] as int,
      successfulPositions: json['successfulPositions'] as int,
      duplicatePositions: json['duplicatePositions'] as int,
      failedPositions: json['failedPositions'] as int,
      accountId: json['accountId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'fileName': fileName,
      'importedAt': importedAt.toIso8601String(),
      'totalPositions': totalPositions,
      'successfulPositions': successfulPositions,
      'duplicatePositions': duplicatePositions,
      'failedPositions': failedPositions,
    };
  }
}
