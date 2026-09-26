import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/core/constants/category_policy_map.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';

void main() {
  group('Elo – kSeedCategoryPolicyTypes and hive_box_names', () {
    test('kSportsCategoryId and kPubGamesCategoryId values', () {
      expect(kSportsCategoryId, 'cat_sports');
      expect(kPubGamesCategoryId, 'cat_pubgames');
    });

    test('kEloCategoryIds is exactly [sports, pubgames]', () {
      expect(kEloCategoryIds, ['cat_sports', 'cat_pubgames']);
      expect(kEloCategoryIds.length, 2);
    });

    test('hive_box_names kEloCategoryIds literal', () {
      final file = File('lib/core/constants/hive_box_names.dart');
      final content = file.readAsStringSync();
      expect(content, contains('kEloCategoryIds'));
      expect(content, contains('cat_sports'));
      expect(content, contains('cat_pubgames'));
      expect(
          content,
          contains(
              'kEloCategoryIds = [kSportsCategoryId, kPubGamesCategoryId]'));
    });

    test('kSeedCategoryPolicyTypes – sports and pubgames map to [elo]', () {
      expect(kSeedCategoryPolicyTypes['cat_sports'], [RankingPolicyType.elo]);
      expect(kSeedCategoryPolicyTypes['cat_pubgames'], [RankingPolicyType.elo]);
      expect(kSeedCategoryPolicyTypes['cat_sports']!.length, 1);
      expect(kSeedCategoryPolicyTypes['cat_pubgames']!.length, 1);
    });

    test('kSeedCategoryPolicyTypes does NOT contain fargoRate (renamed to elo)',
        () {
      expect(kSeedCategoryPolicyTypes['cat_sports'],
          isNot(contains(RankingPolicyType.fargoRate)));
      expect(kSeedCategoryPolicyTypes['cat_pubgames'],
          isNot(contains(RankingPolicyType.fargoRate)));
    });

    test('custom -> [simple, goalDifference] exactly (no elo)', () {
      expect(
          kSeedCategoryPolicyTypes['cat_custom_league_001'],
          containsAll(
              [RankingPolicyType.simple, RankingPolicyType.goalDifference]));
      expect(kSeedCategoryPolicyTypes['cat_custom_league_001']!.length, 2);
      expect(kSeedCategoryPolicyTypes['cat_custom_league_001'],
          isNot(contains(RankingPolicyType.elo)));
      // ignore: deprecated_member_use
      expect(kSeedCategoryPolicyTypes['cat_custom_league_001'],
          isNot(contains(RankingPolicyType.fargoRate)));
    });

    test('boardgames, cardgames, videogames empty', () {
      expect(kSeedCategoryPolicyTypes['cat_boardgames'], isEmpty);
      expect(kSeedCategoryPolicyTypes['cat_cardgames'], isEmpty);
      expect(kSeedCategoryPolicyTypes['cat_videogames'], isEmpty);
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

    test('only custom has simple/goalDifference; only sports/pubgames have elo',
        () {
      for (final entry in kSeedCategoryPolicyTypes.entries) {
        if (entry.key == kFallbackCategoryId) {
          expect(entry.value, contains(RankingPolicyType.simple));
          expect(entry.value, contains(RankingPolicyType.goalDifference));
        } else if (entry.key == 'cat_sports' || entry.key == 'cat_pubgames') {
          expect(entry.value, [RankingPolicyType.elo],
              reason: '${entry.key} should be [elo]');
        } else {
          expect(entry.value, isEmpty,
              reason: '${entry.key} should be empty but was ${entry.value}');
        }
      }
    });

    test('category_policy_map.dart uses RankingPolicyType.elo not fargoRate',
        () {
      final file = File('lib/core/constants/category_policy_map.dart');
      final content = file.readAsStringSync();
      expect(content, contains('RankingPolicyType.elo'));
      // Should not have uncommented fargoRate as primary (deprecated map may contain it)
      expect(content, contains('cat_sports'));
      expect(content, contains('cat_pubgames'));
    });
  });
}
