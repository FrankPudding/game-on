import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';

void main() {
  group('League', () {
    final defaultPolicy = SimpleRankingPolicy(
      id: 'p1',
      name: 'Default',
      pointsForWin: 3,
      pointsForDraw: 1,
      pointsForLoss: 0,
    );

    test('should create League with default values', () {
      final now = DateTime.now();
      final league = League<SimpleMatch>(
        id: '1',
        name: 'Test League',
        createdAt: now,
        rankingPolicy: defaultPolicy,
      );

      expect(league.id, '1');
      expect(league.name, 'Test League');
      expect(league.createdAt, now);
      expect(league.isArchived, false);
      expect(league.rankingPolicy, defaultPolicy);

      final policy = league.rankingPolicy as SimpleRankingPolicy;
      expect(policy.pointsForWin, 3);
      expect(policy.pointsForDraw, 1);
      expect(policy.pointsForLoss, 0);
    });

    test('copyWith should return a new object with updated values', () {
      final now = DateTime.now();
      final league = League<SimpleMatch>(
        id: '1',
        name: 'Test League',
        createdAt: now,
        rankingPolicy: defaultPolicy,
      );

      final updated = league.copyWith(name: 'Updated League', isArchived: true);

      expect(updated.id, league.id);
      expect(updated.name, 'Updated League');
      expect(updated.isArchived, true);
      expect(updated.createdAt, league.createdAt);
      expect(updated.rankingPolicy, league.rankingPolicy);
    });

    group('Edge Cases', () {
      test('should handle zero points for win/draw/loss via policy', () {
        final zeroPolicy = SimpleRankingPolicy(
          id: 'pz',
          name: 'Zero',
          pointsForWin: 0,
          pointsForDraw: 0,
          pointsForLoss: 0,
        );
        final league = League<SimpleMatch>(
          id: '1',
          name: 'Free League',
          createdAt: DateTime.now(),
          rankingPolicy: zeroPolicy,
        );

        final policy = league.rankingPolicy as SimpleRankingPolicy;
        expect(policy.pointsForWin, 0);
        expect(policy.pointsForDraw, 0);
        expect(policy.pointsForLoss, 0);
      });

      test('should handle extremely long names', () {
        final longName = 'A' * 1000;
        final league = League<SimpleMatch>(
          id: '1',
          name: longName,
          createdAt: DateTime.now(),
          rankingPolicy: defaultPolicy,
        );

        expect(league.name, longName);
      });
    });
  });
}
