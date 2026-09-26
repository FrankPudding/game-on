import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/ranking_policies/fargo_rate_ranking_policy.dart';
import 'package:game_on/core/constants/hive_box_names.dart';

void main() {
  group('FargoRateRankingPolicy – categoryIds invariant (set-equality)', () {
    test('accepts exact set in declared order [sports, pubgames]', () {
      final p = FargoRateRankingPolicy(
          id: 'rp1',
          name: 'Fargo',
          leagueId: 'l1',
          categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
          initialRating: 500);
      expect(p.categoryIds, containsAll(kFargoCategoryIds));
      expect(p.categoryIds.length, 2);
    });

    test(
        'accepts exact set reversed order [pubgames, sports] (order-insensitive)',
        () {
      final p = FargoRateRankingPolicy(
          id: 'rp1',
          name: 'Fargo',
          leagueId: 'l1',
          categoryIds: const [kPubGamesCategoryId, kSportsCategoryId],
          initialRating: 500);
      expect(p.categoryIds.toSet(), kFargoCategoryIds.toSet());
    });

    test('validateCategoryIds accepts both orders', () {
      expect(
          () => FargoRateRankingPolicy.validateCategoryIds(
              const [kSportsCategoryId, kPubGamesCategoryId]),
          returnsNormally);
      expect(
          () => FargoRateRankingPolicy.validateCategoryIds(
              const [kPubGamesCategoryId, kSportsCategoryId]),
          returnsNormally);
    });

    test('rejects duplicate ids (e.g. [sports, sports])', () {
      expect(
        () => FargoRateRankingPolicy(
            id: 'rp1',
            name: 'Fargo',
            leagueId: 'l1',
            categoryIds: const [kSportsCategoryId, kSportsCategoryId],
            initialRating: 500),
        throwsArgumentError,
      );
      expect(
          () => FargoRateRankingPolicy.validateCategoryIds(
              const [kSportsCategoryId, kSportsCategoryId]),
          throwsArgumentError);
    });

    test('rejects extra ids (3 elements)', () {
      expect(
        () => FargoRateRankingPolicy(
            id: 'rp1',
            name: 'Fargo',
            leagueId: 'l1',
            categoryIds: const [
              kSportsCategoryId,
              kPubGamesCategoryId,
              'cat_extra'
            ],
            initialRating: 500),
        throwsArgumentError,
      );
      expect(
          () => FargoRateRankingPolicy.validateCategoryIds(const [
                kSportsCategoryId,
                kPubGamesCategoryId,
                kFallbackCategoryId
              ]),
          throwsArgumentError);
    });

    test('rejects missing one id – only sports', () {
      expect(
        () => FargoRateRankingPolicy(
            id: 'rp1',
            name: 'Fargo',
            leagueId: 'l1',
            categoryIds: const [kSportsCategoryId],
            initialRating: 500),
        throwsArgumentError,
      );
    });

    test('rejects only pubgames', () {
      expect(
        () => FargoRateRankingPolicy(
            id: 'rp1',
            name: 'Fargo',
            leagueId: 'l1',
            categoryIds: const [kPubGamesCategoryId],
            initialRating: 500),
        throwsArgumentError,
      );
    });

    test('rejects empty', () {
      expect(
        () => FargoRateRankingPolicy(
            id: 'rp1',
            name: 'Fargo',
            leagueId: 'l1',
            categoryIds: const [],
            initialRating: 500),
        throwsArgumentError,
      );
      expect(() => FargoRateRankingPolicy.validateCategoryIds(const []),
          throwsArgumentError);
    });

    test('rejects singleton custom', () {
      expect(
        () => FargoRateRankingPolicy(
            id: 'rp1',
            name: 'Fargo',
            leagueId: 'l1',
            categoryIds: const [kFallbackCategoryId],
            initialRating: 500),
        throwsArgumentError,
      );
    });

    test('rejects completely unrelated ids', () {
      expect(
        () => FargoRateRankingPolicy(
            id: 'rp1',
            name: 'Fargo',
            leagueId: 'l1',
            categoryIds: const ['cat_boardgames', 'cat_cardgames'],
            initialRating: 500),
        throwsArgumentError,
      );
    });

    test('kFargoCategoryIds constant equals [sports, pubgames]', () {
      expect(kFargoCategoryIds, [kSportsCategoryId, kPubGamesCategoryId]);
      expect(kSportsCategoryId, 'cat_sports');
      expect(kPubGamesCategoryId, 'cat_pubgames');
      expect(FargoRateRankingPolicy.fargoCategoryIds, kFargoCategoryIds);
    });

    test('domain inherits non-empty unique invariant as well', () {
      // duplicate even if not Fargo set should throw ArgumentError (domain base)
      expect(
        () => FargoRateRankingPolicy(
            id: 'rp1',
            name: 'Fargo',
            leagueId: 'l1',
            categoryIds: const ['cat_sports', 'cat_sports', 'cat_pubgames'],
            initialRating: 500),
        throwsArgumentError,
      );
    });
  });
}
