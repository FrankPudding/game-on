import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';

void main() {
  group('RankingPolicyType – Elo renaming', () {
    test('should have 3 variants including elo', () {
      expect(RankingPolicyType.values, contains(RankingPolicyType.simple));
      expect(
          RankingPolicyType.values, contains(RankingPolicyType.goalDifference));
      expect(RankingPolicyType.values, contains(RankingPolicyType.elo));
      expect(RankingPolicyType.values.length, 3);
    });

    test('displayName should return friendly labels – elo Pool', () {
      expect(RankingPolicyType.simple.displayName, 'Simple Scoring');
      expect(RankingPolicyType.goalDifference.displayName, 'Goal Difference');
      expect(RankingPolicyType.elo.displayName, 'Pool');
    });

    test('description should return helpful descriptions – elo Elo Rankings',
        () {
      expect(RankingPolicyType.simple.description, contains('3 for Win'));
      expect(RankingPolicyType.goalDifference.description,
          contains('goal difference'));
      expect(RankingPolicyType.elo.description, 'Elo Rankings');
      expect(RankingPolicyType.elo.description, contains('Elo'));
    });

    test('elo maps to Pool display', () {
      expect(RankingPolicyType.elo.displayName, 'Pool');
      expect(RankingPolicyType.elo.description, 'Elo Rankings');
    });
  });
}
