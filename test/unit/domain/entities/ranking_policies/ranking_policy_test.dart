import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/goal_difference_ranking_policy.dart';

void main() {
  group('SimpleRankingPolicy', () {
    test('should default to standard scoring', () {
      final policy =
          SimpleRankingPolicy(id: 'rp1', name: 'Standard', leagueId: 'l1');

      expect(policy.id, 'rp1');
      expect(policy.name, 'Standard');
      expect(policy.leagueId, 'l1');
      expect(policy.pointsForWin, 3);
      expect(policy.pointsForDraw, 1);
      expect(policy.pointsForLoss, 0);
    });

    test('should accept custom point values', () {
      final policy = SimpleRankingPolicy(
        id: 'rp2',
        name: 'Custom',
        leagueId: 'l2',
        pointsForWin: 5,
        pointsForDraw: 2,
        pointsForLoss: -1,
      );

      expect(policy.pointsForWin, 5);
      expect(policy.pointsForDraw, 2);
      expect(policy.pointsForLoss, -1);
    });
  });

  group('GoalDifferenceRankingPolicy', () {
    test('should default to standard scoring', () {
      final policy =
          GoalDifferenceRankingPolicy(id: 'rp3', name: 'GD', leagueId: 'l3');

      expect(policy.pointsForWin, 3);
      expect(policy.pointsForDraw, 1);
      expect(policy.pointsForLoss, 0);
    });

    test('should accept custom point values', () {
      final policy = GoalDifferenceRankingPolicy(
        id: 'rp4',
        name: 'GD',
        leagueId: 'l4',
        pointsForWin: 5,
        pointsForDraw: 2,
        pointsForLoss: -1,
      );

      expect(policy.pointsForWin, 5);
      expect(policy.pointsForDraw, 2);
      expect(policy.pointsForLoss, -1);
    });
  });
}
