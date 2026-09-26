import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';

void main() {
  group('RankingPolicyType', () {
    test('should have two variants', () {
      // Elo renamed from FargoRate – now 4 variants including deprecated fargoRate
      expect(RankingPolicyType.values.length, 4);
      expect(RankingPolicyType.values, contains(RankingPolicyType.simple));
      expect(
          RankingPolicyType.values, contains(RankingPolicyType.goalDifference));
      expect(RankingPolicyType.values, contains(RankingPolicyType.elo));
      // ignore: deprecated_member_use
      expect(RankingPolicyType.values, contains(RankingPolicyType.fargoRate));
    });

    test('displayName should return friendly labels', () {
      expect(RankingPolicyType.simple.displayName, 'Simple Scoring');
      expect(RankingPolicyType.goalDifference.displayName, 'Goal Difference');
      expect(RankingPolicyType.elo.displayName, 'Pool');
      // ignore: deprecated_member_use
      expect(RankingPolicyType.fargoRate.displayName, 'Pool');
    });

    test('description should return helpful descriptions', () {
      expect(RankingPolicyType.simple.description, contains('3 for Win'));
      expect(RankingPolicyType.goalDifference.description,
          contains('goal difference'));
      expect(RankingPolicyType.elo.description, 'Elo Rankings');
      // ignore: deprecated_member_use
      expect(RankingPolicyType.fargoRate.description, 'Elo Rankings');
    });
  });
}
