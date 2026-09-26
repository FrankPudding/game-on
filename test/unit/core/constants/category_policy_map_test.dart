import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/core/constants/category_policy_map.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';

void main() {
  group('kSeedCategoryPolicyTypes - seed-only map', () {
    test('non-custom categories should have empty allowed types', () {
      expect(kSeedCategoryPolicyTypes['cat_boardgames'], isEmpty,
          reason: 'boardgames should have no allowed types');
      expect(kSeedCategoryPolicyTypes['cat_cardgames'], isEmpty,
          reason: 'cardgames should have no allowed types');
      expect(kSeedCategoryPolicyTypes['cat_sports'], [RankingPolicyType.elo],
          reason: 'sports should have elo');
      expect(kSeedCategoryPolicyTypes['cat_videogames'], isEmpty,
          reason: 'videogames should have no allowed types');
      expect(kSeedCategoryPolicyTypes['cat_pubgames'], [RankingPolicyType.elo],
          reason: 'pubgames should have elo');
    });

    test('custom category should contain both simple and goalDifference', () {
      final custom = kSeedCategoryPolicyTypes[kFallbackCategoryId];
      expect(custom, isNotNull);
      expect(custom, contains(RankingPolicyType.simple));
      expect(custom, contains(RankingPolicyType.goalDifference));
      expect(custom!.length, 2,
          reason: 'custom should have exactly simple and goalDifference');
    });

    test('only custom category should have allowed types', () {
      for (final entry in kSeedCategoryPolicyTypes.entries) {
        if (entry.key == kFallbackCategoryId) {
          expect(entry.value, isNotEmpty);
        } else if (entry.key == 'cat_sports' || entry.key == 'cat_pubgames') {
          expect(entry.value, [RankingPolicyType.elo],
              reason: '${entry.key} should be [elo]');
        } else {
          expect(entry.value, isEmpty,
              reason: '${entry.key} should be empty but was ${entry.value}');
        }
      }
    });

    test('map should contain exactly 5 entries', () {
      expect(kSeedCategoryPolicyTypes.length, 6);
      expect(
          kSeedCategoryPolicyTypes.keys,
          containsAll([
            'cat_boardgames',
            'cat_cardgames',
            'cat_sports',
            'cat_videogames',
            'cat_pubgames',
            kFallbackCategoryId,
          ]));
    });

    test(
        'custom entry should not be empty and non-custom entries should not contain simple',
        () {
      for (final id in [
        'cat_boardgames',
        'cat_cardgames',
        'cat_sports',
        'cat_videogames',
        'cat_pubgames'
      ]) {
        expect(kSeedCategoryPolicyTypes[id],
            isNot(contains(RankingPolicyType.simple)));
        expect(kSeedCategoryPolicyTypes[id],
            isNot(contains(RankingPolicyType.goalDifference)));
      }
    });
  });
}
