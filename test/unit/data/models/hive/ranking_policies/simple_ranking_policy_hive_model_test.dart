import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/data/models/hive/ranking_policies/simple_ranking_policy_hive_model.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';

void main() {
  group('SimpleRankingPolicyHiveModel', () {
    test('fromDomain should map all fields', () {
      final policy = SimpleRankingPolicy(
        id: 'rp1',
        name: 'Standard',
        leagueId: 'l1',
        pointsForWin: 3,
        pointsForDraw: 1,
        pointsForLoss: 0,
      );

      final model = SimpleRankingPolicyHiveModel.fromDomain(policy);

      expect(model.id, 'rp1');
      expect(model.name, 'Standard');
      expect(model.leagueId, 'l1');
      expect(model.pointsForWin, 3);
      expect(model.pointsForDraw, 1);
      expect(model.pointsForLoss, 0);
    });

    test('toDomain should map all fields', () {
      final model = SimpleRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Standard',
        leagueId: 'l1',
        pointsForWin: 5,
        pointsForDraw: 2,
        pointsForLoss: 1,
      );

      final policy = model.toDomain();

      expect(policy.id, 'rp1');
      expect(policy.name, 'Standard');
      expect(policy.leagueId, 'l1');
      expect(policy.pointsForWin, 5);
      expect(policy.pointsForDraw, 2);
      expect(policy.pointsForLoss, 1);
    });

    test('toDomain should handle null leagueId', () {
      final model = SimpleRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Standard',
        leagueId: null,
      );

      final policy = model.toDomain();

      expect(policy.leagueId, isEmpty);
    });

    test('should default to standard scoring', () {
      final model = SimpleRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Standard',
        leagueId: 'l1',
      );

      expect(model.pointsForWin, 3);
      expect(model.pointsForDraw, 1);
      expect(model.pointsForLoss, 0);
    });
  });
}
