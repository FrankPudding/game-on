import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/data/models/hive/ranking_policies/goal_difference_ranking_policy_hive_model.dart';
import 'package:game_on/domain/entities/ranking_policies/goal_difference_ranking_policy.dart';

void main() {
  group('GoalDifferenceRankingPolicyHiveModel', () {
    test('fromDomain should map all fields', () {
      final policy = GoalDifferenceRankingPolicy(
        id: 'rp1',
        name: 'GD',
        leagueId: 'l1',
        pointsForWin: 3,
        pointsForDraw: 1,
        pointsForLoss: 0,
      );

      final model = GoalDifferenceRankingPolicyHiveModel.fromDomain(policy);

      expect(model.id, 'rp1');
      expect(model.name, 'GD');
      expect(model.leagueId, 'l1');
      expect(model.pointsForWin, 3);
      expect(model.pointsForDraw, 1);
      expect(model.pointsForLoss, 0);
    });

    test('toDomain should map all fields', () {
      final model = GoalDifferenceRankingPolicyHiveModel(
        id: 'rp1',
        name: 'GD',
        leagueId: 'l1',
        pointsForWin: 3,
        pointsForDraw: 1,
        pointsForLoss: 0,
      );

      final policy = model.toDomain();

      expect(policy.id, 'rp1');
      expect(policy.name, 'GD');
      expect(policy.leagueId, 'l1');
      expect(policy.pointsForWin, 3);
      expect(policy.pointsForDraw, 1);
      expect(policy.pointsForLoss, 0);
    });

    test('toDomain should handle null leagueId', () {
      final model = GoalDifferenceRankingPolicyHiveModel(
        id: 'rp1',
        name: 'GD',
        leagueId: null,
      );

      final policy = model.toDomain();

      expect(policy.leagueId, isEmpty);
    });
  });
}
