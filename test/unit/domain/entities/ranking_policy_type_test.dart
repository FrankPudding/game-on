import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';

void main() {
  group('RankingPolicyType', () {
    test('should have four variants', () {
      expect(RankingPolicyType.values.length, 4);
      expect(RankingPolicyType.values, contains(RankingPolicyType.simple));
      expect(
          RankingPolicyType.values, contains(RankingPolicyType.goalDifference));
      expect(RankingPolicyType.values, contains(RankingPolicyType.elo));
      expect(RankingPolicyType.values, contains(RankingPolicyType.tableTennisElo));
    });

    test('displayName should return friendly labels', () {
      expect(RankingPolicyType.simple.displayName, 'Simple Scoring');
      expect(RankingPolicyType.goalDifference.displayName, 'Goal Difference');
      expect(RankingPolicyType.elo.displayName, 'Pool');
      expect(RankingPolicyType.tableTennisElo.displayName, 'Table Tennis');
    });

    test('description should return helpful descriptions', () {
      expect(RankingPolicyType.simple.description, contains('3 for Win'));
      expect(RankingPolicyType.goalDifference.description,
          contains('goal difference'));
      expect(RankingPolicyType.elo.description, 'Elo Rankings');
      expect(RankingPolicyType.tableTennisElo.description, 'Table Tennis Elo');
    });
  });
}
