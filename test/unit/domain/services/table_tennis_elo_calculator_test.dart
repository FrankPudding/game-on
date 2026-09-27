import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/services/table_tennis_elo_calculator.dart';

LeaguePlayer _player(String id) => LeaguePlayer(
      id: id,
      userId: 'u_$id',
      leagueId: 'l1',
      name: 'Player $id',
      avatarColorHex: 'AE0C00',
    );

SimpleMatch _ttMatch({
  required String id,
  required DateTime playedAt,
  bool isComplete = true,
  bool isDraw = false,
  required String winnerSideId,
  required int winnerScore,
  required int loserScore,
  required String winnerPlayerId,
  required String loserPlayerId,
}) {
  final s1 = Side(id: 's_${id}_1', playerIds: [winnerPlayerId], score: winnerScore);
  final s2 = Side(id: 's_${id}_2', playerIds: [loserPlayerId], score: loserScore);
  return SimpleMatch(
    id: id,
    leagueId: 'l1',
    playedAt: playedAt,
    isComplete: isComplete,
    isDraw: isDraw,
    sides: [s1, s2],
    winnerSideId: winnerSideId,
  );
}

void main() {
  const calculator = TableTennisEloCalculator();
  final p1 = _player('p1');
  final p2 = _player('p2');

  group('TableTennisEloCalculator – pure domain & score/margin multipliers', () {
    test('is pure domain service – no Flutter/Hive imports', () {
      final file = File('lib/domain/services/table_tennis_elo_calculator.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('package:flutter'), isFalse);
      expect(content.contains('package:hive'), isFalse);
    });

    test('throws ArgumentError if scores are missing (null)', () {
      final m = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1'], score: null),
          Side(id: 's2', playerIds: ['p2'], score: 11),
        ],
        winnerSideId: 's2',
      );
      expect(
        () => calculator.calculate(matches: [m], players: [p1, p2], initialRating: 400),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError if scores are negative', () {
      final m = _ttMatch(
        id: 'm1',
        playedAt: DateTime(2024, 1, 1),
        winnerSideId: 's_m1_1',
        winnerScore: 11,
        loserScore: -1,
        winnerPlayerId: 'p1',
        loserPlayerId: 'p2',
      );
      expect(
        () => calculator.calculate(matches: [m], players: [p1, p2], initialRating: 400),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError if scores are equal (isDraw == true or scores equal)', () {
      final m = _ttMatch(
        id: 'm1',
        playedAt: DateTime(2024, 1, 1),
        isDraw: true,
        winnerSideId: 's_m1_1',
        winnerScore: 10,
        loserScore: 10,
        winnerPlayerId: 'p1',
        loserPlayerId: 'p2',
      );
      expect(
        () => calculator.calculate(matches: [m], players: [p1, p2], initialRating: 400),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError if winning margin < 2', () {
      final m = _ttMatch(
        id: 'm1',
        playedAt: DateTime(2024, 1, 1),
        winnerSideId: 's_m1_1',
        winnerScore: 11,
        loserScore: 10, // margin 1 < 2
        winnerPlayerId: 'p1',
        loserPlayerId: 'p2',
      );
      expect(
        () => calculator.calculate(matches: [m], players: [p1, p2], initialRating: 400),
        throwsArgumentError,
      );
    });

    test('margin multipliers: min margin <= 2 (1.0x), clean sweep loserScore==0 or margin >=21 (2.0x), linear scaling in between', () {
      final resMin = calculator.calculate(
        matches: [
          _ttMatch(
            id: 'm1',
            playedAt: DateTime(2024, 1, 1),
            winnerSideId: 's_m1_1',
            winnerScore: 11,
            loserScore: 9, // margin 2 -> 1.0x
            winnerPlayerId: 'p1',
            loserPlayerId: 'p2',
          )
        ],
        players: [p1, p2],
        initialRating: 400,
      );
      expect(resMin['p1']!.rating, 410);
      expect(resMin['p2']!.rating, 390);

      final resCleanSweep = calculator.calculate(
        matches: [
          _ttMatch(
            id: 'm2',
            playedAt: DateTime(2024, 1, 1),
            winnerSideId: 's_m2_1',
            winnerScore: 11,
            loserScore: 0, // clean sweep -> 2.0x
            winnerPlayerId: 'p1',
            loserPlayerId: 'p2',
          )
        ],
        players: [p1, p2],
        initialRating: 400,
      );
      expect(resCleanSweep['p1']!.rating, 420);
      expect(resCleanSweep['p2']!.rating, 380);
    });

    test('calculates correct ratings and statistics (matchesPlayed, wins, losses, rating, winRate)', () {
      final res = calculator.calculate(
        matches: [
          _ttMatch(
            id: 'm1',
            playedAt: DateTime(2024, 1, 1),
            winnerSideId: 's_m1_1',
            winnerScore: 11,
            loserScore: 5,
            winnerPlayerId: 'p1',
            loserPlayerId: 'p2',
          )
        ],
        players: [p1, p2],
        initialRating: 400,
      );
      expect(res['p1']!.matchesPlayed, 1);
      expect(res['p1']!.wins, 1);
      expect(res['p1']!.losses, 0);
      expect(res['p1']!.rating, greaterThan(410));
      expect(res['p1']!.winRate, 1.0);

      expect(res['p2']!.matchesPlayed, 1);
      expect(res['p2']!.wins, 0);
      expect(res['p2']!.losses, 1);
      expect(res['p2']!.rating, lessThan(390));
      expect(res['p2']!.winRate, 0.0);
    });
  });
}
