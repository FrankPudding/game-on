import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/core/constants/category_policy_map.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';

void main() {
  group('Fargo constants', () {
    test('kSportsCategoryId and kPubGamesCategoryId values', () {
      expect(kSportsCategoryId, 'cat_sports');
      expect(kPubGamesCategoryId, 'cat_pubgames');
    });

    test('kFargoCategoryIds is exactly [sports, pubgames]', () {
      expect(kFargoCategoryIds, ['cat_sports', 'cat_pubgames']);
      expect(kFargoCategoryIds.length, 2);
    });

    test('kFargoInitialRating is 500', () {
      expect(kFargoInitialRating, 500);
    });
  });

  group('RankingPolicyType.fargoRate', () {
    test('enum contains fargoRate', () {
      expect(RankingPolicyType.values, contains(RankingPolicyType.fargoRate));
      expect(RankingPolicyType.values, contains(RankingPolicyType.elo));
      expect(RankingPolicyType.values.length, 4);
    });

    test('displayName is Pool', () {
      expect(RankingPolicyType.fargoRate.displayName, 'Pool');
      expect(RankingPolicyType.elo.displayName, 'Pool');
    });

    test('description contains FargoRate Rankings', () {
      // Renamed to Elo Rankings – both elo and deprecated fargoRate now return Elo Rankings
      expect(RankingPolicyType.fargoRate.description, contains('Elo Rankings'));
      expect(RankingPolicyType.elo.description, contains('Elo Rankings'));
    });
  });

  group('kSeedCategoryPolicyTypes – Fargo seeds', () {
    test('sports -> [fargoRate]', () {
      expect(kSeedCategoryPolicyTypes['cat_sports'], [RankingPolicyType.elo]);
    });

    test('pubgames -> [fargoRate]', () {
      expect(kSeedCategoryPolicyTypes['cat_pubgames'], [RankingPolicyType.elo]);
    });

    test('boardgames empty', () {
      expect(kSeedCategoryPolicyTypes['cat_boardgames'], isEmpty);
    });

    test('cardgames empty', () {
      expect(kSeedCategoryPolicyTypes['cat_cardgames'], isEmpty);
    });

    test('videogames empty', () {
      expect(kSeedCategoryPolicyTypes['cat_videogames'], isEmpty);
    });

    test('custom -> [simple, goalDifference] exactly', () {
      expect(
          kSeedCategoryPolicyTypes['cat_custom_league_001'],
          containsAll(
              [RankingPolicyType.simple, RankingPolicyType.goalDifference]));
      expect(kSeedCategoryPolicyTypes['cat_custom_league_001']!.length, 2);
      expect(kSeedCategoryPolicyTypes['cat_custom_league_001'],
          isNot(contains(RankingPolicyType.fargoRate)));
    });

    test('map contains 6 entries total', () {
      expect(kSeedCategoryPolicyTypes.length, 6);
      expect(
          kSeedCategoryPolicyTypes.keys,
          containsAll([
            'cat_boardgames',
            'cat_cardgames',
            'cat_sports',
            'cat_videogames',
            'cat_custom_league_001',
            'cat_pubgames'
          ]));
    });
  });
}
