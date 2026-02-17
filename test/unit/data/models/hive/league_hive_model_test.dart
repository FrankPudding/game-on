import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/data/models/hive/league_hive_model.dart';
import 'package:game_on/domain/entities/league.dart';

void main() {
  group('LeagueHiveModel', () {
    final testDate = DateTime(2023, 1, 1);

    test('should convert from domain correctly', () {
      final league = League(
        id: '1',
        name: 'Test League',
        createdAt: testDate,
        isArchived: true,
      );

      final model = LeagueHiveModel.fromDomain(league);

      expect(model.id, '1');
      expect(model.name, 'Test League');
      expect(model.createdAt, testDate);
      expect(model.isArchived, true);
    });

    test('should convert to domain correctly', () {
      final model = LeagueHiveModel(
        id: '1',
        name: 'Test League',
        createdAt: testDate,
        isArchived: false,
      );

      final league = model.toDomain();

      expect(league.id, '1');
      expect(league.name, 'Test League');
      expect(league.createdAt, testDate);
      expect(league.isArchived, false);
    });

    // We can't easily test the binary deserialization here without mocking Hive internals
    // but we can verify the model structure supports our assumptions.
  });
}
