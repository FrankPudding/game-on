import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/simple_match.dart';

void main() {
  group('SimpleMatch', () {
    test('should create SimpleMatch with given values', () {
      final now = DateTime.now();
      final match = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: now,
        isComplete: true,
        isDraw: false,
        winnerId: 'p1',
      );

      expect(match.id, 'm1');
      expect(match.leagueId, 'l1');
      expect(match.playedAt, now);
      expect(match.isComplete, true);
      expect(match.isDraw, false);
      expect(match.winnerId, 'p1');
    });

    test('copyWith should return updated object', () {
      final now = DateTime.now();
      final match = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: now,
        isComplete: false,
      );

      final updated = match.copyWith(isComplete: true, isDraw: true);

      expect(updated.id, match.id);
      expect(updated.isComplete, true);
      expect(updated.isDraw, true);
    });

    group('Edge Cases', () {
      test('should allow matches in the future', () {
        final futureDate = DateTime.now().add(const Duration(days: 1));
        final match = SimpleMatch(
          id: 'm1',
          leagueId: 'l1',
          playedAt: futureDate,
          isComplete: false,
        );

        expect(match.playedAt, futureDate);
      });

      test('should allow winnerId to be null for draws', () {
        final match = SimpleMatch(
          id: 'm1',
          leagueId: 'l1',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: true,
          winnerId: null,
        );

        expect(match.isDraw, true);
        expect(match.winnerId, isNull);
      });

      test(
          'should allow winnerId to be set even if isDraw is true (though logical error, entity allows it)',
          () {
        // The entity itself doesn't enforce logic between isDraw and winnerId,
        // that's usually handled by the repository or service.
        final match = SimpleMatch(
          id: 'm1',
          leagueId: 'l1',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: true,
          winnerId: 'p1',
        );

        expect(match.isDraw, true);
        expect(match.winnerId, 'p1');
      });
    });
  });
}
