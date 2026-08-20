import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';

void main() {
  group('RankingPolicyType', () {
    test('should have two variants', () {
      expect(RankingPolicyType.values, [
        RankingPolicyType.simple,
        RankingPolicyType.goalDifference,
      ]);
    });

    test('displayName should return friendly labels', () {
      expect(RankingPolicyType.simple.displayName, 'Simple Scoring');
      expect(RankingPolicyType.goalDifference.displayName, 'Goal Difference');
    });

    test('description should return helpful descriptions', () {
      expect(RankingPolicyType.simple.description, contains('3 for Win'));
      expect(RankingPolicyType.goalDifference.description,
          contains('goal difference'));
    });
  });
}
