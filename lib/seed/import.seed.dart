import '../model/import.model.dart';

final List<Import> seedImports = [
  Import(
    id: 'imp_001',
    accountId: 'acc_001',
    fileName: 'account_history_nov.html',
    importedAt: DateTime.parse('2026-11-02T11:00:00Z'),
    totalPositions: 25,
    successfulPositions: 20,
    duplicatePositions: 3,
    failedPositions: 2,
  ),
  Import(
    id: 'imp_002',
    accountId: 'acc_002',
    fileName: 'vtmarkets_live_nov.html',
    importedAt: DateTime.parse('2026-11-04T10:00:00Z'),
    totalPositions: 12,
    successfulPositions: 12,
    duplicatePositions: 0,
    failedPositions: 0,
  ),
  Import(
    id: 'imp_003',
    accountId: 'acc_003',
    fileName: 'icmarkets_raw_nov.html',
    importedAt: DateTime.parse('2026-11-05T08:00:00Z'),
    totalPositions: 8,
    successfulPositions: 7,
    duplicatePositions: 1,
    failedPositions: 0,
  ),
  Import(
    id: 'imp_004',
    accountId: 'acc_004',
    fileName: 'exness_zero_nov.html',
    importedAt: DateTime.parse('2026-11-05T18:00:00Z'),
    totalPositions: 15,
    successfulPositions: 14,
    duplicatePositions: 1,
    failedPositions: 0,
  ),
];
