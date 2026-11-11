import '../model/user.model.dart';

final User seedUser = User(
  id: 'usr_001',
  name: 'Ki Arifin',
  email: 'arifin@example.com',
  passwordHash: r'$2b$12$hashed_password',
  createdAt: DateTime.parse('2026-11-02T09:00:00Z'),
  updatedAt: DateTime.parse('2026-11-02T09:00:00Z'),
);

final List<User> seedUsers = [seedUser];
