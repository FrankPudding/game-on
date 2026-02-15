import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';

void main() {
  group('SimpleMatch', () {
    final side1 = Side(id: 's1', playerIds: ['p1']);
    final side2 = Side(id: 's2', playerIds: ['p2']);

    test('should create SimpleMatch with given values', () {
      final now = DateTime.now();
      final match = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: now,
        isComplete: true,
        isDraw: false,
        sides: [side1, side2],
        winnerSideId: 's1',
      );

      expect(match.id, 'm1');
      expect(match.leagueId, 'l1');
      expect(match.playedAt, now);
      expect(match.isComplete, true);
      expect(match.isDraw, false);
      expect(match.sides, [side1, side2]);
      expect(match.winnerSideId, 's1');
    });

    test('copyWith should return updated object', () {
      final now = DateTime.now();
      final match = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: now,
        isComplete: false,
        sides: [side1, side2],
      );

      final updated = match.copyWith(isComplete: true, isDraw: true);

      expect(updated.id, match.id);
      expect(updated.isComplete, true);
      expect(updated.isDraw, true);
      expect(updated.sides, match.sides);
    });

    group('Edge Cases', () {
      test('should allow matches in the future', () {
        final futureDate = DateTime.now().add(const Duration(days: 1));
        final match = SimpleMatch(
          id: 'm1',
          leagueId: 'l1',
          playedAt: futureDate,
          isComplete: false,
          sides: [side1, side2],
        );

        expect(match.playedAt, futureDate);
      });

      test('should allow winnerSideId to be null for draws', () {
        final match = SimpleMatch(
          id: 'm1',
          leagueId: 'l1',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: true,
          sides: [side1, side2],
          winnerSideId: null,
        );

        expect(match.isDraw, true);
        expect(match.winnerSideId, isNull);
      });

      test(
          'should allow winnerSideId to be set even if isDraw is true (though logical error, entity allows it)',
          () {
        final match = SimpleMatch(
          id: 'm1',
          leagueId: 'l1',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: true,
          sides: [side1, side2],
          winnerSideId: 's1',
        );

        expect(match.isDraw, true);
        expect(match.winnerSideId, 's1');
      });
    });
  });
}
