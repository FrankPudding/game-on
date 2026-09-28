import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/domain/entities/ranking_policies/table_tennis_elo_ranking_policy.dart';

void main() {
  group('TableTennisEloRankingPolicy – initialRating validation 100..500 inclusive', () {
    test('validateInitialRating accepts lower bound 100', () {
      expect(
          () => TableTennisEloRankingPolicy.validateInitialRating(100), returnsNormally);
    });
    test('validateInitialRating accepts default 400', () {
      expect(
          () => TableTennisEloRankingPolicy.validateInitialRating(400), returnsNormally);
    });
    test('validateInitialRating accepts upper bound 500', () {
      expect(
          () => TableTennisEloRankingPolicy.validateInitialRating(500), returnsNormally);
    });
    test('validateInitialRating rejects 99 below range throws ArgumentError', () {
      expect(() => TableTennisEloRankingPolicy.validateInitialRating(99),
          throwsArgumentError);
    });
    test('validateInitialRating rejects 501 above range throws ArgumentError', () {
      expect(() => TableTennisEloRankingPolicy.validateInitialRating(501),
          throwsArgumentError);
    });
    test('validateInitialRating rejects 0 and 1000 outside range', () {
      expect(() => TableTennisEloRankingPolicy.validateInitialRating(0),
          throwsArgumentError);
      expect(() => TableTennisEloRankingPolicy.validateInitialRating(1000),
          throwsArgumentError);
    });
    test('constructor requires initialRating and stores it – 400', () {
      final p = TableTennisEloRankingPolicy(
        id: 'tt1',
        name: 'Table Tennis League',
        leagueId: 'l1',
        categoryIds: const [kTableTennisCategoryId],
        initialRating: 400,
      );
      expect(p.initialRating, 400);
    });
    test('constructor rejects invalid initialRating 99 or 501', () {
      expect(
        () => TableTennisEloRankingPolicy(
          id: 'tt1',
          name: 'Table Tennis League',
          leagueId: 'l1',
          categoryIds: const [kTableTennisCategoryId],
          initialRating: 99,
        ),
        throwsArgumentError,
      );
      expect(
        () => TableTennisEloRankingPolicy(
          id: 'tt1',
          name: 'Table Tennis League',
          leagueId: 'l1',
          categoryIds: const [kTableTennisCategoryId],
          initialRating: 501,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TableTennisEloRankingPolicy – categoryIds invariant', () {
    test('accepts exact set [cat_tabletennis]', () {
      final p = TableTennisEloRankingPolicy(
        id: 'tt1',
        name: 'Table Tennis',
        leagueId: 'l1',
        categoryIds: const [kTableTennisCategoryId],
        initialRating: 400,
      );
      expect(p.categoryIds, [kTableTennisCategoryId]);
    });

    test('validateCategoryIds accepts [cat_tabletennis]', () {
      expect(
          () => TableTennisEloRankingPolicy.validateCategoryIds(
              const [kTableTennisCategoryId]),
          returnsNormally);
    });

    test('rejects empty categoryIds', () {
      expect(
        () => TableTennisEloRankingPolicy(
          id: 'tt1',
          name: 'Table Tennis',
          leagueId: 'l1',
          categoryIds: const [],
          initialRating: 400,
        ),
        throwsArgumentError,
      );
      expect(() => TableTennisEloRankingPolicy.validateCategoryIds(const []),
          throwsArgumentError);
    });

    test('rejects wrong categoryId (e.g. cat_sports)', () {
      expect(
        () => TableTennisEloRankingPolicy(
          id: 'tt1',
          name: 'Table Tennis',
          leagueId: 'l1',
          categoryIds: const ['cat_sports'],
          initialRating: 400,
        ),
        throwsArgumentError,
      );
    });

    test('rejects extra categoryIds', () {
      expect(
        () => TableTennisEloRankingPolicy(
          id: 'tt1',
          name: 'Table Tennis',
          leagueId: 'l1',
          categoryIds: const [kTableTennisCategoryId, 'cat_sports'],
          initialRating: 400,
        ),
        throwsArgumentError,
      );
    });

    test('preserves pure domain – no Flutter/Hive imports', () {
      final file = File('lib/domain/entities/ranking_policies/table_tennis_elo_ranking_policy.dart');
      final content = file.readAsStringSync();
      expect(content.contains('package:flutter'), isFalse);
      expect(content.contains('package:hive'), isFalse);
    });
  });
}
