import '../model/broker.model.dart';

final List<Broker> seedBrokers = [
  Broker(
    id: 'brk_001',
    name: 'VT Markets',
    website: 'https://www.vtmarkets.com',
    createdAt: DateTime.parse('2026-11-02T09:00:00Z'),
  ),
  Broker(
    id: 'brk_002',
    name: 'FTMO',
    website: 'https://ftmo.com',
    createdAt: DateTime.parse('2026-11-02T09:05:00Z'),
  ),
  Broker(
    id: 'brk_003',
    name: 'IC Markets',
    website: 'https://www.icmarkets.com',
    createdAt: DateTime.parse('2026-11-02T09:10:00Z'),
  ),
  Broker(
    id: 'brk_004',
    name: 'Exness',
    website: 'https://www.exness.com',
    createdAt: DateTime.parse('2026-11-02T09:15:00Z'),
  ),
];
