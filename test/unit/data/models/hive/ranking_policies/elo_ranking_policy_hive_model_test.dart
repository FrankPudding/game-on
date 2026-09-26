import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.dart';
import 'package:game_on/domain/entities/ranking_policies/elo_ranking_policy.dart';
import 'package:game_on/core/constants/hive_box_names.dart';

void main() {
  group('EloRankingPolicyHiveModel', () {
    test('typeId is 12', () {
      final adapter = EloRankingPolicyHiveModelAdapter();
      expect(adapter.typeId, 12);
    });

    test(
        'typeId keeps 12 (same as Fargo) – file declares @HiveType(typeId: 12)',
        () {
      final file = File(
          'lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.dart');
      final content = file.readAsStringSync();
      expect(content, contains('@HiveType(typeId: 12)'));
    });

    test('HiveField 7 initialRating literal 500 for codegen', () {
      final file = File(
          'lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.dart');
      final content = file.readAsStringSync();
      expect(content, contains('@HiveField(7, defaultValue: 500)'));
      expect(content, contains('final int initialRating'));
    });

    test('generated adapter still defaults missing field 7 to 500 (legacy)',
        () {
      final adapterFile = File(
          'lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.g.dart');
      expect(adapterFile.existsSync(), isTrue);
      final content = adapterFile.readAsStringSync();
      expect(content, contains('fields[7] == null ? 500'));
    });

    test('legacy missing field 7 -> 500 default', () {
      final model = EloRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
      );
      expect(model.initialRating, 500);
      final policy = model.toDomain();
      expect(policy.initialRating, 500);
    });

    test(
        'fromDomain maps all fields with defensive List.from copy and initialRating',
        () {
      final policy = EloRankingPolicy(
          id: 'rp1',
          name: 'Pool',
          leagueId: 'l1',
          categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
          initialRating: 400);
      final model = EloRankingPolicyHiveModel.fromDomain(policy);
      expect(model.id, 'rp1');
      expect(model.name, 'Pool');
      expect(model.leagueId, 'l1');
      expect(model.categoryIds, [kSportsCategoryId, kPubGamesCategoryId]);
      expect(model.initialRating, 400);
      // defensive copy: mutating original list should not affect model
      final mutable = [kSportsCategoryId, kPubGamesCategoryId];
      final p2 = EloRankingPolicy(
          id: 'rp2',
          name: 'Pool',
          leagueId: 'l1',
          categoryIds: mutable,
          initialRating: 400);
      final m2 = EloRankingPolicyHiveModel.fromDomain(p2);
      mutable.add('extra');
      expect(m2.categoryIds, isNot(contains('extra')));
      expect(m2.initialRating, 400);
    });

    test(
        'fromDomain preserves reversed order but toDomain still validates set-equality',
        () {
      final policy = EloRankingPolicy(
          id: 'rp1',
          name: 'Pool',
          leagueId: 'l1',
          categoryIds: const [kPubGamesCategoryId, kSportsCategoryId],
          initialRating: 400);
      final model = EloRankingPolicyHiveModel.fromDomain(policy);
      expect(model.categoryIds, [kPubGamesCategoryId, kSportsCategoryId]);
      final back = model.toDomain();
      expect(back.categoryIds.toSet(), kEloCategoryIds.toSet());
    });

    test('toDomain maps all fields and returns List.unmodifiable', () {
      final model = EloRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 400,
      );
      final policy = model.toDomain();
      expect(policy.id, 'rp1');
      expect(policy.name, 'Pool');
      expect(policy.leagueId, 'l1');
      expect(policy.categoryIds, [kSportsCategoryId, kPubGamesCategoryId]);
      expect(policy.initialRating, 400);
      expect(
          () => (policy.categoryIds as List).add('x'), throwsUnsupportedError);
    });

    test('round-trip preserves 400 and 500 and 100 boundaries', () {
      for (final rating in [100, 400, 500]) {
        final policy = EloRankingPolicy(
            id: 'rp1',
            name: 'Pool',
            leagueId: 'l1',
            categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
            initialRating: rating);
        final model = EloRankingPolicyHiveModel.fromDomain(policy);
        final back = model.toDomain();
        expect(back.initialRating, rating);
      }
    });

    test(
        'toDomain throws ArgumentError when initialRating out-of-range (corruption)',
        () {
      final corruptedLow = EloRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 99,
      );
      expect(() => corruptedLow.toDomain(), throwsArgumentError);
      final corruptedHigh = EloRankingPolicyHiveModel(
        id: 'rp2',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 501,
      );
      expect(() => corruptedHigh.toDomain(), throwsArgumentError);
    });

    test('toDomain throws StateError when categoryIds empty (corruption)', () {
      final model = EloRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [],
        initialRating: 400,
      );
      expect(() => model.toDomain(), throwsStateError);
    });

    test('toDomain validates categoryIds exactly sports+pubgames', () {
      final wrong = EloRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId],
        initialRating: 400,
      );
      expect(() => wrong.toDomain(), throwsArgumentError);
    });

    test('toDomain handles null leagueId as empty string', () {
      final model = EloRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: null,
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 400,
      );
      final policy = model.toDomain();
      expect(policy.leagueId, isEmpty);
    });

    test('adapter has correct typeId 12 and equality', () {
      final adapter = EloRankingPolicyHiveModelAdapter();
      expect(adapter.typeId, 12);
      final adapter2 = EloRankingPolicyHiveModelAdapter();
      expect(adapter, equals(adapter2));
      expect(adapter.hashCode, adapter2.hashCode);
    });

    test('defensive copy via List.from on write – file contains List.from', () {
      final file = File(
          'lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.dart');
      final content = file.readAsStringSync();
      expect(content, contains('List.from'));
    });

    test('hiveDbVersion stays 3', () {
      final file = File('lib/core/config.dart');
      final content = file.readAsStringSync();
      expect(content, contains('hiveDbVersion = 3'));
    });

    test('Hive registrar registers Elo adapter (typeId 12)', () {
      final file = File('lib/hive_registrar.g.dart');
      final content = file.readAsStringSync();
      expect(content, contains('EloRankingPolicyHiveModelAdapter'));
      expect(content,
          contains('registerAdapter(EloRankingPolicyHiveModelAdapter'));
    });

    test('Fargo typedef still resolves to Elo hive model', () {
      // ignore: deprecated_member_use
      final model = FargoRateRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 400,
      );
      expect(model, isA<EloRankingPolicyHiveModel>());
      expect(model.initialRating, 400);
      // ignore: deprecated_member_use
      final adapter = FargoRateRankingPolicyHiveModelAdapter();
      expect(adapter.typeId, 12);
    });
  });
}
