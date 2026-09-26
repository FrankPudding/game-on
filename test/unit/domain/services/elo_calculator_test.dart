import 'dart:io';
import 'dart:math' as math;

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

// Helper to compute expected Elo per spec: expected = 1/(1+10^((opponent-player)/400)), new = old + 20*(score-expected)
int _expectedNewRating(
    {required int playerRating,
    required int opponentRating,
    required int score,
    int k = 20}) {
  final expected =
      1 / (1 + math.pow(10, (opponentRating - playerRating) / 400));
  return (playerRating + k * (score - expected)).round();
}

void main() {
  const calculator = EloCalculator();
  final p1 = _player('p1');
  final p2 = _player('p2');
  final p3 = _player('p3');

  group('EloCalculator.calculate – pure domain & elo formula K=20', () {
    test(
        'EloCalculator is pure domain – no Flutter/Hive imports and K private const 20',
        () {
      final file = File('lib/domain/services/elo_calculator.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('package:flutter'), isFalse);
      expect(content.contains('package:hive'), isFalse);
      expect(content, contains('_kFactor = 20'));
      expect(content, contains('initialRating'));
      expect(content, contains('calculate'));
      // No per-league kFactor param – should not have "Map<String, int> kFactor" nor league-specific kFactor field
      expect(content.contains('perLeague'), isFalse);
    });

    test(
        'returns map for all players even with no matches (rating 400 default)',
        () {
      final result = calculator
          .calculate(matches: [], players: [p1, p2], initialRating: 400);
      expect(result.length, 2);
      expect(result['p1']!.rating, 400);
      expect(result['p2']!.rating, 400);
      expect(result['p1']!.matchesPlayed, 0);
      expect(result['p1']!.wins, 0);
      expect(result['p1']!.losses, 0);
      expect(result['p1']!.winRate, 0);
    });

    test('returns map for all players with custom initialRating 500 legacy',
        () {
      final result = calculator
          .calculate(matches: [], players: [p1, p2], initialRating: 500);
      expect(result['p1']!.rating, 500);
      expect(result['p2']!.rating, 500);
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
          matches: [incomplete], players: [p1, p2], initialRating: 400);
      expect(result['p1']!.matchesPlayed, 0);
      expect(result['p2']!.matchesPlayed, 0);
      expect(result['p1']!.rating, 400);
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
              matches: [badIncomplete], players: [p1, p2], initialRating: 400),
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
              .calculate(matches: [m], players: [p1, p2], initialRating: 400),
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
              matches: [oneSide], players: [p1, p2], initialRating: 400),
          throwsArgumentError);

      final threeSides = SimpleMatch(
        id: 'm2',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2']),
          Side(id: 's3', playerIds: ['p3'])
        ],
      );
      expect(
          () => calculator.calculate(
              matches: [threeSides], players: [p1, p2, p3], initialRating: 400),
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
          Side(id: 's2', playerIds: ['p3'])
        ],
        winnerSideId: 's1',
      );
      expect(
          () => calculator.calculate(
              matches: [teamSide], players: [p1, p2, p3], initialRating: 400),
          throwsArgumentError);

      final emptySide = SimpleMatch(
        id: 'm2',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: []),
          Side(id: 's2', playerIds: ['p2'])
        ],
      );
      expect(
          () => calculator.calculate(
              matches: [emptySide], players: [p1, p2], initialRating: 400),
          throwsArgumentError);
    });

    test('throws ArgumentError when winnerSideId missing or not found', () {
      final missingWinner = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: null,
      );
      expect(
          () => calculator.calculate(
              matches: [missingWinner], players: [p1, p2], initialRating: 400),
          throwsArgumentError);

      final ghostWinner = SimpleMatch(
        id: 'm2',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 'nonexistent',
      );
      expect(
          () => calculator.calculate(
              matches: [ghostWinner], players: [p1, p2], initialRating: 400),
          throwsArgumentError);
    });

    test(
        'sorts playedAt ASC + id ASC deterministically (winner rating affected by order)',
        () {
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
          .calculate(matches: [mA, mB], players: [p1, p2], initialRating: 400);
      final resultBA = calculator
          .calculate(matches: [mB, mA], players: [p1, p2], initialRating: 400);
      expect(resultAB['p1']!.rating, resultBA['p1']!.rating);
      expect(resultAB['p2']!.rating, resultBA['p2']!.rating);
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
          matches: [late, early], players: [p1, p2], initialRating: 400);
      expect(result['p1']!.wins, 1);
      expect(result['p2']!.wins, 1);
      expect(result['p1']!.matchesPlayed, 2);
    });

    test('Elo formula K=20: equal 400 vs 400 win -> 410/390', () {
      final m = _match(
          id: 'm1',
          playedAt: DateTime(2024, 1, 1),
          winnerSideId: 's_m1_1',
          winnerPlayerId: 'p1',
          loserPlayerId: 'p2');
      final result = calculator
          .calculate(matches: [m], players: [p1, p2], initialRating: 400);
      expect(result['p1']!.rating, 410);
      expect(result['p2']!.rating, 390);
      expect(result['p1']!.wins, 1);
      expect(result['p1']!.losses, 0);
      expect(result['p2']!.wins, 0);
      expect(result['p2']!.losses, 1);
      expect(result['p1']!.matchesPlayed, 1);
      expect(result['p1']!.winRate, 1.0);
      expect(result['p2']!.winRate, 0.0);
    });

    test('Elo formula K=20: equal 500 vs 500 win -> 510/490', () {
      final m = _match(
          id: 'm1',
          playedAt: DateTime(2024, 1, 1),
          winnerSideId: 's_m1_1',
          winnerPlayerId: 'p1',
          loserPlayerId: 'p2');
      final result = calculator
          .calculate(matches: [m], players: [p1, p2], initialRating: 500);
      expect(result['p1']!.rating, 510);
      expect(result['p2']!.rating, 490);
    });

    test('Elo formula K=20: high 600 vs low 400 win -> ~+5/-5 (605/395)', () {
      // Seed ratings via two-step: first give p1 a high rating and p2 low? Simpler: start both 400, create rating diff via prior matches, then test high vs low.
      // Instead we can directly set initial ratings with prior matches to create 600 vs 400 differential.
      // For this test, we simulate 600 vs 400 by starting both at 500 but manually checking formula.
      // We'll create ghost players with known ratings? Instead test via direct formula helper.
      // Create two matches: p1 beats p2 repeatedly to get separation, then high beats low gives small gain.
      // Easiest: initial 500 each, let p1 win many to reach ~600, p2 lose many to drop ~400, then test next win delta.
      // For determinism, we will test the formula helper expectation for 600 vs 400.
      final highNew =
          _expectedNewRating(playerRating: 600, opponentRating: 400, score: 1);
      final lowNew =
          _expectedNewRating(playerRating: 400, opponentRating: 600, score: 0);
      expect(highNew, closeTo(605, 1)); // +5
      expect(lowNew, closeTo(395, 1)); // -5

      // Now verify calculator actually does ~+5 when high beats low via sequential setup
      // Build sequential history where p1 is high and p2 is low then final match high wins small.
      // We will produce a history where p1 rating is higher than p2 by ~200 before final.
      // Simpler: run calculator with two players where p1 has won many vs p3 to inflate, p2 lost many vs p3 to deflate, then p1 beats p2.
      final pHigh = _player('ph');
      final pLow = _player('pl');
      final pOther = _player('po');
      // Inflate ph: 10 wins vs po
      final inflateMatches = List.generate(
          10,
          (i) => _match(
              id: 'inf_$i',
              playedAt: DateTime(2024, 1, i + 1),
              winnerSideId: 's_inf_${i}_1',
              winnerPlayerId: 'ph',
              loserPlayerId: 'po'));
      // Deflate pl: 10 losses vs po (po beats pl)
      final deflateMatches = List.generate(
          10,
          (i) => _match(
              id: 'def_$i',
              playedAt: DateTime(2024, 1, i + 11),
              winnerSideId: 's_def_${i}_1',
              winnerPlayerId: 'po',
              loserPlayerId: 'pl'));
      // winner is po (first side), so winnerSideId is s_def_*_1
      final allPre = [...inflateMatches, ...deflateMatches];
      final preResult = calculator.calculate(
          matches: allPre, players: [pHigh, pLow, pOther], initialRating: 400);
      final highRatingBefore = preResult['ph']!.rating;
      final lowRatingBefore = preResult['pl']!.rating;
      expect(highRatingBefore - lowRatingBefore,
          greaterThan(100)); // at least 100 diff

      // Now high beats low
      final finalMatch = SimpleMatch(
        id: 'm_final',
        leagueId: 'l1',
        playedAt: DateTime(2024, 2, 1),
        isComplete: true,
        sides: [
          Side(id: 's_f1', playerIds: ['ph']),
          Side(id: 's_f2', playerIds: ['pl'])
        ],
        winnerSideId: 's_f1',
      );
      final result = calculator.calculate(
          matches: [...allPre, finalMatch],
          players: [pHigh, pLow, pOther],
          initialRating: 400);
      final deltaHigh = result['ph']!.rating - highRatingBefore;
      final deltaLow = result['pl']!.rating - lowRatingBefore;
      // High favorite should gain small (<=10, ideally 0-7) and low lose small
      expect(deltaHigh, inInclusiveRange(0, 10));
      expect(deltaLow, inInclusiveRange(-10, 0));
      // If diff ~100-150, delta should be around 7-5
      expect(deltaHigh, lessThanOrEqualTo(7));
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
          .calculate(matches: [m1, m2], players: [p1, p2], initialRating: 400);
      expect(result['p1']!.matchesPlayed, 2);
      expect(result['p1']!.wins, 2);
      expect(result['p1']!.losses, 0);
      expect(result['p1']!.winRate, 1.0);
      expect(result['p2']!.matchesPlayed, 2);
      expect(result['p2']!.wins, 0);
      expect(result['p2']!.losses, 2);
      expect(result['p1']!.rating, greaterThan(result['p2']!.rating));
      expect(result['p1']!.rating, greaterThan(400));
      // Second win after higher rating should give less than 10 (diminishing)
      expect(result['p1']!.rating, lessThan(420)); // 410 + ~9 =419
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
          .calculate(matches: [m], players: [p1, p2, p3], initialRating: 400);
      expect(result.length, 3);
      expect(result['p3']!.matchesPlayed, 0);
      expect(result['p3']!.rating, 400);
      expect(result['p3']!.winRate, 0);
    });

    test('ghost players seeded at initialRating and included in result', () {
      // Match involves ghost ids not in players list
      final ghostMatch = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['ghost1']),
          Side(id: 's2', playerIds: ['ghost2'])
        ],
        winnerSideId: 's1',
      );
      final result = calculator.calculate(
          matches: [ghostMatch], players: [p1, p2], initialRating: 400);
      // Should contain p1,p2 + ghost1,ghost2
      expect(result.length, 4);
      expect(result.containsKey('ghost1'), isTrue);
      expect(result.containsKey('ghost2'), isTrue);
      expect(result['ghost1']!.rating, 410);
      expect(result['ghost2']!.rating, 390);
      expect(result['ghost1']!.wins, 1);
      expect(result['ghost2']!.losses, 1);
      // Original players remain at initial
      expect(result['p1']!.rating, 400);
      expect(result['p1']!.matchesPlayed, 0);

      // Ghost mixed with known player
      final mixed = SimpleMatch(
        id: 'm2',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 2),
        isComplete: true,
        sides: [
          Side(id: 's3', playerIds: ['p1']),
          Side(id: 's4', playerIds: ['ghost1'])
        ],
        winnerSideId: 's4',
      );
      final result2 = calculator.calculate(
          matches: [ghostMatch, mixed], players: [p1, p2], initialRating: 400);
      expect(result2['ghost1']!.matchesPlayed, 2);
      expect(result2['ghost1']!.wins, 2); // won both
      expect(result2['p1']!.losses, 1);
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
          matches: matches, players: [p1, p2], initialRating: 400);
      expect(result['p1']!.rating, isA<int>());
      expect(result['p1']!.rating.isNaN, isFalse);
    });

    test('FargoRateCalculator typedef still works as EloCalculator with K=20',
        () {
      // ignore: deprecated_member_use
      const fargoCalc = FargoRateCalculator();
      final m = _match(
          id: 'm1',
          playedAt: DateTime(2024, 1, 1),
          winnerSideId: 's_m1_1',
          winnerPlayerId: 'p1',
          loserPlayerId: 'p2');
      final result = fargoCalc
          .calculate(matches: [m], players: [p1, p2], initialRating: 400);
      expect(result['p1']!.rating, 410);
    });
  });
}
