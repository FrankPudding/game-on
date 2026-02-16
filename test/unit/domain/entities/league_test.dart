import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/league.dart';

void main() {
  group('League', () {
    test('should create League with default values', () {
      final now = DateTime.now();
      final league = League(
        id: '1',
        name: 'Test League',
        createdAt: now,
      );

      expect(league.id, '1');
      expect(league.name, 'Test League');
      expect(league.createdAt, now);
      expect(league.isArchived, false);
    });

    test('copyWith should return a new object with updated values', () {
      final now = DateTime.now();
      final league = League(
        id: '1',
        name: 'Test League',
        createdAt: now,
      );

      final updated = league.copyWith(name: 'Updated League', isArchived: true);

      expect(updated.id, league.id);
      expect(updated.name, 'Updated League');
      expect(updated.isArchived, true);
      expect(updated.createdAt, league.createdAt);
    });

    group('Edge Cases', () {
      test('should handle extremely long names', () {
        final longName = 'A' * 1000;
        final league = League(
          id: '1',
          name: longName,
          createdAt: DateTime.now(),
        );

        expect(league.name, longName);
      });
    });
  });
}
