import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';

void main() {
  group('RankingPolicyType – Elo renaming', () {
    test('should have 4 variants including elo and deprecated fargoRate', () {
      expect(RankingPolicyType.values, contains(RankingPolicyType.simple));
      expect(
          RankingPolicyType.values, contains(RankingPolicyType.goalDifference));
      expect(RankingPolicyType.values, contains(RankingPolicyType.elo));
      // ignore: deprecated_member_use
      expect(RankingPolicyType.values, contains(RankingPolicyType.fargoRate));
      expect(RankingPolicyType.values.length, 4);
    });

    test('displayName should return friendly labels – elo Pool', () {
      expect(RankingPolicyType.simple.displayName, 'Simple Scoring');
      expect(RankingPolicyType.goalDifference.displayName, 'Goal Difference');
      expect(RankingPolicyType.elo.displayName, 'Pool');
      // ignore: deprecated_member_use
      expect(RankingPolicyType.fargoRate.displayName, 'Pool');
      // elo and fargoRate displayName should be same (backward compat)
      expect(RankingPolicyType.elo.displayName,
          RankingPolicyType.fargoRate.displayName);
    });

    test('description should return helpful descriptions – elo Elo Rankings',
        () {
      expect(RankingPolicyType.simple.description, contains('3 for Win'));
      expect(RankingPolicyType.goalDifference.description,
          contains('goal difference'));
      expect(RankingPolicyType.elo.description, 'Elo Rankings');
      // ignore: deprecated_member_use
      expect(RankingPolicyType.fargoRate.description, 'Elo Rankings');
      expect(RankingPolicyType.elo.description, contains('Elo'));
    });

    test('deprecated fargoRate still maps to same strings as elo', () {
      // ignore: deprecated_member_use
      expect(RankingPolicyType.fargoRate.displayName, 'Pool');
      // ignore: deprecated_member_use
      expect(RankingPolicyType.fargoRate.description, 'Elo Rankings');
    });
  });
}
