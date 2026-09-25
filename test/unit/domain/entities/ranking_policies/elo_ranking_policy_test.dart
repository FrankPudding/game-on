import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/ranking_policies/elo_ranking_policy.dart';
import 'package:game_on/core/constants/hive_box_names.dart';

void main() {
  group('EloRankingPolicy – initialRating validation 100..500 inclusive', () {
    test('validateInitialRating accepts lower bound 100', () {
      expect(
          () => EloRankingPolicy.validateInitialRating(100), returnsNormally);
    });
    test('validateInitialRating accepts default 400', () {
      expect(
          () => EloRankingPolicy.validateInitialRating(400), returnsNormally);
    });
    test('validateInitialRating accepts upper bound 500 legacy', () {
      expect(
          () => EloRankingPolicy.validateInitialRating(500), returnsNormally);
    });
    test('validateInitialRating rejects 99 below range throws ArgumentError',
        () {
      expect(() => EloRankingPolicy.validateInitialRating(99),
          throwsArgumentError);
    });
    test('validateInitialRating rejects 501 above range throws ArgumentError',
        () {
      expect(() => EloRankingPolicy.validateInitialRating(501),
          throwsArgumentError);
    });
    test('validateInitialRating rejects 0 and 1000 outside custom range', () {
      expect(
          () => EloRankingPolicy.validateInitialRating(0), throwsArgumentError);
      expect(() => EloRankingPolicy.validateInitialRating(1000),
          throwsArgumentError);
    });
    test(
        'validateInitialRating throws ArgumentError not StateError/UnimplementedError',
        () {
      try {
        EloRankingPolicy.validateInitialRating(99);
        fail('should throw');
      } catch (e) {
        expect(e, isA<ArgumentError>());
        expect(e, isNot(isA<UnimplementedError>()));
      }
    });
    test('constructor requires initialRating and stores it – 400', () {
      final p = EloRankingPolicy(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 400,
      );
      expect(p.initialRating, 400);
    });
    test('constructor accepts 100 and 500 boundaries', () {
      final low = EloRankingPolicy(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 100,
      );
      final high = EloRankingPolicy(
        id: 'rp2',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 500,
      );
      expect(low.initialRating, 100);
      expect(high.initialRating, 500);
    });
    test('constructor rejects initialRating 99 throws ArgumentError', () {
      expect(
        () => EloRankingPolicy(
          id: 'rp1',
          name: 'Pool',
          leagueId: 'l1',
          categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
          initialRating: 99,
        ),
        throwsArgumentError,
      );
    });
    test('constructor rejects initialRating 501 throws ArgumentError', () {
      expect(
        () => EloRankingPolicy(
          id: 'rp1',
          name: 'Pool',
          leagueId: 'l1',
          categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
          initialRating: 501,
        ),
        throwsArgumentError,
      );
    });
    test('constructor still validates categoryIds set-equality', () {
      expect(
        () => EloRankingPolicy(
          id: 'rp1',
          name: 'Pool',
          leagueId: 'l1',
          categoryIds: const [kSportsCategoryId],
          initialRating: 400,
        ),
        throwsArgumentError,
      );
    });
  });

  group('EloRankingPolicy – categoryIds invariant (set-equality)', () {
    test('accepts exact set in declared order [sports, pubgames]', () {
      final p = EloRankingPolicy(
          id: 'rp1',
          name: 'Elo',
          leagueId: 'l1',
          categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
          initialRating: 400);
      expect(p.categoryIds, containsAll(kEloCategoryIds));
      expect(p.categoryIds.length, 2);
    });

    test(
        'accepts exact set reversed order [pubgames, sports] (order-insensitive)',
        () {
      final p = EloRankingPolicy(
          id: 'rp1',
          name: 'Elo',
          leagueId: 'l1',
          categoryIds: const [kPubGamesCategoryId, kSportsCategoryId],
          initialRating: 400);
      expect(p.categoryIds.toSet(), kEloCategoryIds.toSet());
    });

    test('validateCategoryIds accepts both orders', () {
      expect(
          () => EloRankingPolicy.validateCategoryIds(
              const [kSportsCategoryId, kPubGamesCategoryId]),
          returnsNormally);
      expect(
          () => EloRankingPolicy.validateCategoryIds(
              const [kPubGamesCategoryId, kSportsCategoryId]),
          returnsNormally);
    });

    test('rejects duplicate ids (e.g. [sports, sports])', () {
      expect(
        () => EloRankingPolicy(
            id: 'rp1',
            name: 'Elo',
            leagueId: 'l1',
            categoryIds: const [kSportsCategoryId, kSportsCategoryId],
            initialRating: 400),
        throwsArgumentError,
      );
      expect(
          () => EloRankingPolicy.validateCategoryIds(
              const [kSportsCategoryId, kSportsCategoryId]),
          throwsArgumentError);
    });

    test('rejects extra ids (3 elements)', () {
      expect(
        () => EloRankingPolicy(
            id: 'rp1',
            name: 'Elo',
            leagueId: 'l1',
            categoryIds: const [
              kSportsCategoryId,
              kPubGamesCategoryId,
              'cat_extra'
            ],
            initialRating: 400),
        throwsArgumentError,
      );
      expect(
          () => EloRankingPolicy.validateCategoryIds(const [
                kSportsCategoryId,
                kPubGamesCategoryId,
                kFallbackCategoryId
              ]),
          throwsArgumentError);
    });

    test('rejects missing one id – only sports', () {
      expect(
        () => EloRankingPolicy(
            id: 'rp1',
            name: 'Elo',
            leagueId: 'l1',
            categoryIds: const [kSportsCategoryId],
            initialRating: 400),
        throwsArgumentError,
      );
    });

    test('rejects only pubgames', () {
      expect(
        () => EloRankingPolicy(
            id: 'rp1',
            name: 'Elo',
            leagueId: 'l1',
            categoryIds: const [kPubGamesCategoryId],
            initialRating: 400),
        throwsArgumentError,
      );
    });

    test('rejects empty', () {
      expect(
        () => EloRankingPolicy(
            id: 'rp1',
            name: 'Elo',
            leagueId: 'l1',
            categoryIds: const [],
            initialRating: 400),
        throwsArgumentError,
      );
      expect(() => EloRankingPolicy.validateCategoryIds(const []),
          throwsArgumentError);
    });

    test('rejects singleton custom', () {
      expect(
        () => EloRankingPolicy(
            id: 'rp1',
            name: 'Elo',
            leagueId: 'l1',
            categoryIds: const [kFallbackCategoryId],
            initialRating: 400),
        throwsArgumentError,
      );
    });

    test('rejects completely unrelated ids', () {
      expect(
        () => EloRankingPolicy(
            id: 'rp1',
            name: 'Elo',
            leagueId: 'l1',
            categoryIds: const ['cat_boardgames', 'cat_cardgames'],
            initialRating: 400),
        throwsArgumentError,
      );
    });

    test('kEloCategoryIds constant equals [sports, pubgames]', () {
      expect(kEloCategoryIds, [kSportsCategoryId, kPubGamesCategoryId]);
      expect(kSportsCategoryId, 'cat_sports');
      expect(kPubGamesCategoryId, 'cat_pubgames');
      expect(EloRankingPolicy.eloCategoryIds, kEloCategoryIds);
    });

    test('fargoCategoryIds deprecated still equals elo', () {
      // ignore: deprecated_member_use
      expect(EloRankingPolicy.fargoCategoryIds, kEloCategoryIds);
      // ignore: deprecated_member_use
      expect(kFargoCategoryIds, kEloCategoryIds);
    });

    test('FargoRateRankingPolicy typedef still works as Elo', () {
      // ignore: deprecated_member_use
      final p = FargoRateRankingPolicy(
          id: 'rp1',
          name: 'Pool',
          leagueId: 'l1',
          categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
          initialRating: 400);
      expect(p, isA<EloRankingPolicy>());
      expect(p.initialRating, 400);
    });

    test('preserves DDD pure domain – no Flutter/Hive imports', () {
      final file =
          File('lib/domain/entities/ranking_policies/elo_ranking_policy.dart');
      final content = file.readAsStringSync();
      expect(content.contains('package:flutter'), isFalse);
      expect(content.contains('package:hive'), isFalse);
      expect(content, contains('validateInitialRating'));
      expect(content, contains('validateCategoryIds'));
      expect(content, contains('SetEquality'));
      // Must use SetEquality + length guard per plan
      expect(content, contains('SetEquality'));
    });
  });
}
