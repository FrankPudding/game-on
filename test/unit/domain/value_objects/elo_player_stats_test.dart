import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/value_objects/elo_player_stats.dart';

void main() {
  group('EloPlayerStats VO – pure domain', () {
    test('winRate 0 when matchesPlayed 0', () {
      const s =
          EloPlayerStats(matchesPlayed: 0, wins: 0, losses: 0, rating: 400);
      expect(s.winRate, 0);
    });

    test('winRate wins/matchesPlayed – 3 wins 1 loss => 0.75', () {
      const s =
          EloPlayerStats(matchesPlayed: 4, wins: 3, losses: 1, rating: 512);
      expect(s.winRate, closeTo(0.75, 0.0001));
    });

    test('winRate 1.0 when all wins', () {
      const s =
          EloPlayerStats(matchesPlayed: 5, wins: 5, losses: 0, rating: 600);
      expect(s.winRate, 1.0);
    });

    test('winRate 0.0 when all losses but played', () {
      const s =
          EloPlayerStats(matchesPlayed: 2, wins: 0, losses: 2, rating: 450);
      expect(s.winRate, 0.0);
    });

    test('winRate 0.5 for 1 win 1 loss', () {
      const s =
          EloPlayerStats(matchesPlayed: 2, wins: 1, losses: 1, rating: 400);
      expect(s.winRate, 0.5);
    });

    test('copyWith preserves unchanged fields', () {
      const original =
          EloPlayerStats(matchesPlayed: 2, wins: 1, losses: 1, rating: 400);
      final copied = original.copyWith(rating: 420);
      expect(copied.matchesPlayed, 2);
      expect(copied.wins, 1);
      expect(copied.losses, 1);
      expect(copied.rating, 420);
      expect(copied.winRate, 0.5);
    });

    test('copyWith can update wins and matchesPlayed => winRate recomputed',
        () {
      const original =
          EloPlayerStats(matchesPlayed: 0, wins: 0, losses: 0, rating: 400);
      final updated =
          original.copyWith(matchesPlayed: 3, wins: 2, losses: 1, rating: 410);
      expect(updated.matchesPlayed, 3);
      expect(updated.wins, 2);
      expect(updated.winRate, closeTo(0.6667, 0.001));
    });

    test('copyWith with no args returns equal values', () {
      const s =
          EloPlayerStats(matchesPlayed: 1, wins: 1, losses: 0, rating: 410);
      final c = s.copyWith();
      expect(c.matchesPlayed, 1);
      expect(c.wins, 1);
      expect(c.losses, 0);
      expect(c.rating, 410);
    });

    test('deprecated FargoPlayerStats typedef still works', () {
      // ignore: deprecated_member_use
      const s =
          FargoPlayerStats(matchesPlayed: 1, wins: 1, losses: 0, rating: 410);
      expect(s.rating, 410);
      expect(s.winRate, 1.0);
    });

    test('EloPlayerStats is pure – no Flutter/Hive imports', () {
      final file = File('lib/domain/value_objects/elo_player_stats.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('import \'package:flutter'), isFalse);
      expect(content.contains('import \'package:hive'), isFalse);
      expect(content.contains('hive'), isFalse);
    });
  });
}
