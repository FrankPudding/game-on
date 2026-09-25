import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/services/fargo_rate_calculator.dart';

LeaguePlayer _player(String id) => LeaguePlayer(
      id: id,
      userId: 'u_$id',
      leagueId: 'l1',
      name: 'Player $id',
      avatarColorHex: 'AE0C00',
    );

SimpleMatch _match({
  required String id,
  required DateTime playedAt,
  bool isComplete = true,
  bool isDraw = false,
  required String winnerSideId,
  required String winnerPlayerId,
  required String loserPlayerId,
  List<Side>? sides,
}) {
  final s1 = Side(id: 's_${id}_1', playerIds: [winnerPlayerId]);
  final s2 = Side(id: 's_${id}_2', playerIds: [loserPlayerId]);
  return SimpleMatch(
    id: id,
    leagueId: 'l1',
    playedAt: playedAt,
    isComplete: isComplete,
    isDraw: isDraw,
    sides: sides ?? [s1, s2],
    winnerSideId: winnerSideId,
  );
}

void main() {
  const calculator = FargoRateCalculator();
  final p1 = _player('p1');
  final p2 = _player('p2');
  final p3 = _player('p3');

  group('FargoRateCalculator.calculate', () {
    test('returns map for all players even with no matches (rating 500)', () {
      final result = calculator
          .calculate(matches: [], players: [p1, p2], initialRating: 500);
      expect(result.length, 2);
      expect(result['p1']!.rating, 500);
      expect(result['p2']!.rating, 500);
      expect(result['p1']!.matchesPlayed, 0);
      expect(result['p1']!.wins, 0);
      expect(result['p1']!.losses, 0);
      expect(result['p1']!.winRate, 0);
    });

    test(
        'filters where(isComplete) before sort – incomplete ignored not counted not throwing',
        () {
      final incomplete = SimpleMatch(
        id: 'm_inc',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: false,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      final result = calculator.calculate(
          matches: [incomplete], players: [p1, p2], initialRating: 500);
      expect(result['p1']!.matchesPlayed, 0);
      expect(result['p2']!.matchesPlayed, 0);
      expect(result['p1']!.rating, 500);
    });

    test(
        'incomplete with invalid sides (draw, 1 side) does NOT throw because filtered',
        () {
      final badIncomplete = SimpleMatch(
        id: 'm_bad',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: false,
        isDraw: true,
        sides: [
          Side(id: 's1', playerIds: ['p1', 'p2'])
        ],
      );
      expect(
          () => calculator.calculate(
              matches: [badIncomplete], players: [p1, p2], initialRating: 500),
          returnsNormally);
    });

    test('throws ArgumentError on isDraw==true (complete)', () {
      final m = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        isDraw: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
      );
      expect(
          () => calculator
              .calculate(matches: [m], players: [p1, p2], initialRating: 500),
          throwsArgumentError);
    });

    test('throws ArgumentError when sides.length !=2', () {
      final oneSide = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1'])
        ],
      );
      expect(
          () => calculator.calculate(
              matches: [oneSide], players: [p1, p2], initialRating: 500),
          throwsArgumentError);

      final threeSides = SimpleMatch(
        id: 'm2',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2']),
          Side(id: 's3', playerIds: ['p3']),
        ],
      );
      expect(
          () => calculator.calculate(
              matches: [threeSides], players: [p1, p2, p3], initialRating: 500),
          throwsArgumentError);
    });

    test('throws ArgumentError when any playerIds.length !=1', () {
      final teamSide = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1', 'p2']),
          Side(id: 's2', playerIds: ['p3']),
        ],
        winnerSideId: 's1',
      );
      expect(
          () => calculator.calculate(
              matches: [teamSide], players: [p1, p2, p3], initialRating: 500),
          throwsArgumentError);

      final emptySide = SimpleMatch(
        id: 'm2',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: []),
          Side(id: 's2', playerIds: ['p2']),
        ],
      );
      expect(
          () => calculator.calculate(
              matches: [emptySide], players: [p1, p2], initialRating: 500),
          throwsArgumentError);
    });

    test(
        'sorts playedAt ASC + id ASC deterministically (winner rating affected by order)',
        () {
      // Two matches same playedAt, different id: m_a vs m_b.
      // p1 beats p2 in m_a, then p2 beats p1 in m_b. Order matters for ELO.
      final sameDate = DateTime(2024, 1, 1);
      final mA = SimpleMatch(
        id: 'm_a',
        leagueId: 'l1',
        playedAt: sameDate,
        isComplete: true,
        sides: [
          Side(id: 's_a1', playerIds: ['p1']),
          Side(id: 's_a2', playerIds: ['p2'])
        ],
        winnerSideId: 's_a1',
      );
      final mB = SimpleMatch(
        id: 'm_b',
        leagueId: 'l1',
        playedAt: sameDate,
        isComplete: true,
        sides: [
          Side(id: 's_b1', playerIds: ['p1']),
          Side(id: 's_b2', playerIds: ['p2'])
        ],
        winnerSideId: 's_b2',
      );

      final resultAB = calculator
          .calculate(matches: [mA, mB], players: [p1, p2], initialRating: 500);
      final resultBA = calculator
          .calculate(matches: [mB, mA], players: [p1, p2], initialRating: 500);
      // Both orderings given same set should yield same result because both sorted ASC id -> a then b
      expect(resultAB['p1']!.rating, resultBA['p1']!.rating);
      expect(resultAB['p2']!.rating, resultBA['p2']!.rating);
      // Winner of first match gains rating >500, loser <500 after first, then second reverses partially
      // After two opposite results ratings should be symmetric around 500 but not exactly 500
      expect(resultAB['p1']!.matchesPlayed, 2);
      expect(resultAB['p1']!.wins, 1);
      expect(resultAB['p1']!.losses, 1);
    });

    test('playedAt ASC ordering before id', () {
      final early = _match(
          id: 'm1',
          playedAt: DateTime(2024, 1, 1),
          winnerSideId: 's_m1_1',
          winnerPlayerId: 'p1',
          loserPlayerId: 'p2');
      final late = _match(
          id: 'm2',
          playedAt: DateTime(2024, 1, 2),
          winnerSideId: 's_m2_1',
          winnerPlayerId: 'p2',
          loserPlayerId: 'p1');
      final result = calculator.calculate(
          matches: [late, early], players: [p1, p2], initialRating: 500);
      // If sorted correctly, early first then late. Both players 1-1.
      expect(result['p1']!.wins, 1);
      expect(result['p2']!.wins, 1);
      expect(result['p1']!.matchesPlayed, 2);
    });

    test(
        'updates 500 initial rating ELO-like: winner increases, loser decreases',
        () {
      final m = _match(
          id: 'm1',
          playedAt: DateTime(2024, 1, 1),
          winnerSideId: 's_m1_1',
          winnerPlayerId: 'p1',
          loserPlayerId: 'p2');
      final result = calculator
          .calculate(matches: [m], players: [p1, p2], initialRating: 500);
      expect(result['p1']!.rating, greaterThan(500));
      expect(result['p2']!.rating, lessThan(500));
      expect(result['p1']!.wins, 1);
      expect(result['p1']!.losses, 0);
      expect(result['p2']!.wins, 0);
      expect(result['p2']!.losses, 1);
      expect(result['p1']!.matchesPlayed, 1);
      expect(result['p1']!.winRate, 1.0);
      expect(result['p2']!.winRate, 0.0);
    });

    test('multiple matches: stats accumulate correctly', () {
      final m1 = _match(
          id: 'm1',
          playedAt: DateTime(2024, 1, 1),
          winnerSideId: 's_m1_1',
          winnerPlayerId: 'p1',
          loserPlayerId: 'p2');
      final m2 = _match(
          id: 'm2',
          playedAt: DateTime(2024, 1, 2),
          winnerSideId: 's_m2_1',
          winnerPlayerId: 'p1',
          loserPlayerId: 'p2');
      final result = calculator
          .calculate(matches: [m1, m2], players: [p1, p2], initialRating: 500);
      expect(result['p1']!.matchesPlayed, 2);
      expect(result['p1']!.wins, 2);
      expect(result['p1']!.losses, 0);
      expect(result['p1']!.winRate, 1.0);
      expect(result['p2']!.matchesPlayed, 2);
      expect(result['p2']!.wins, 0);
      expect(result['p2']!.losses, 2);
      expect(result['p1']!.rating, greaterThan(result['p2']!.rating));
      expect(result['p1']!.rating, greaterThan(500));
    });

    test('returns map for all players even with 3 players but only 2 involved',
        () {
      final m = _match(
          id: 'm1',
          playedAt: DateTime(2024, 1, 1),
          winnerSideId: 's_m1_1',
          winnerPlayerId: 'p1',
          loserPlayerId: 'p2');
      final result = calculator
          .calculate(matches: [m], players: [p1, p2, p3], initialRating: 500);
      expect(result.length, 3);
      expect(result['p3']!.matchesPlayed, 0);
      expect(result['p3']!.rating, 500);
      expect(result['p3']!.winRate, 0);
    });

    test('rating stays integer and not NaN after many matches', () {
      final matches = List.generate(
          5,
          (i) => _match(
              id: 'm$i',
              playedAt: DateTime(2024, 1, i + 1),
              winnerSideId: 's_m${i}_1',
              winnerPlayerId: 'p1',
              loserPlayerId: 'p2'));
      final result = calculator.calculate(
          matches: matches, players: [p1, p2], initialRating: 500);
      expect(result['p1']!.rating, isA<int>());
      expect(result['p1']!.rating.isNaN, isFalse);
    });
  });
}
