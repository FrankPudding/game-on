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
      expect(league.pointsForWin, 3);
      expect(league.pointsForDraw, 1);
      expect(league.pointsForLoss, 0);
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
      test('should handle zero points for win/draw/loss', () {
        final league = League(
          id: '1',
          name: 'Free League',
          createdAt: DateTime.now(),
          pointsForWin: 0,
          pointsForDraw: 0,
          pointsForLoss: 0,
        );

        expect(league.pointsForWin, 0);
        expect(league.pointsForDraw, 0);
        expect(league.pointsForLoss, 0);
      });

      test('should handle negative points (e.g., penalty)', () {
        final league = League(
          id: '1',
          name: 'Hardcore League',
          createdAt: DateTime.now(),
          pointsForLoss: -5,
        );

        expect(league.pointsForLoss, -5);
      });

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
