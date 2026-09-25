import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/constants/elo_constants.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/core/config.dart';

void main() {
  group('Elo constants – elo_constants.dart', () {
    test('kEloMinRating is 100', () {
      expect(kEloMinRating, 100);
    });
    test('kEloMaxRating is 500', () {
      expect(kEloMaxRating, 500);
    });
    test('kEloDefaultInitialRating is 400', () {
      expect(kEloDefaultInitialRating, 400);
    });
    test('kEloLegacyInitialRating is 500', () {
      expect(kEloLegacyInitialRating, 500);
    });
    test('kEloDefaultKFactor is 20', () {
      expect(kEloDefaultKFactor, 20);
    });
    test(
        'range invariant 100..500 inclusive, default inside legacy inside default != legacy',
        () {
      expect(kEloMinRating, lessThan(kEloMaxRating));
      expect(kEloDefaultInitialRating, greaterThanOrEqualTo(kEloMinRating));
      expect(kEloDefaultInitialRating, lessThanOrEqualTo(kEloMaxRating));
      expect(kEloLegacyInitialRating, greaterThanOrEqualTo(kEloMinRating));
      expect(kEloLegacyInitialRating, lessThanOrEqualTo(kEloMaxRating));
      expect(kEloDefaultInitialRating, isNot(kEloLegacyInitialRating));
    });
    test('hiveDbVersion stays 3 (no bump)', () {
      expect(AppConfig().hiveDbVersion, 3);
    });
    test(
        'hive_box_names retains deprecated literal kFargoInitialRating=500 and kElo aliases',
        () {
      // ignore: deprecated_member_use
      expect(kFargoInitialRating, 500);
      expect(kEloCategoryIds, [kSportsCategoryId, kPubGamesCategoryId]);
      // ignore: deprecated_member_use
      expect(kFargoCategoryIds, kEloCategoryIds);
      expect(kEloCategoryIds.length, 2);
      expect(kSportsCategoryId, 'cat_sports');
      expect(kPubGamesCategoryId, 'cat_pubgames');
    });
    test('deprecated fargo aliases still equal elo values', () {
      // ignore: deprecated_member_use
      expect(kFargoMinRating, kEloMinRating);
      // ignore: deprecated_member_use
      expect(kFargoMaxRating, kEloMaxRating);
      // ignore: deprecated_member_use
      expect(kFargoDefaultInitialRating, kEloDefaultInitialRating);
      // ignore: deprecated_member_use
      expect(kFargoLegacyInitialRating, kEloLegacyInitialRating);
      // ignore: deprecated_member_use
      expect(kFargoDefaultKFactor, kEloDefaultKFactor);
    });
    test(
        'elo_constants.dart has no imports (single source, no cycle, pure domain)',
        () {
      final file = File('lib/domain/constants/elo_constants.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('import '), isFalse,
          reason: 'elo_constants.dart must have no imports per plan');
      expect(content, contains('kEloMinRating'));
      expect(content, contains('kEloMaxRating'));
      expect(content, contains('kEloDefaultInitialRating'));
      expect(content, contains('kEloLegacyInitialRating'));
      expect(content, contains('kEloDefaultKFactor'));
    });
    test('elo_constants literal values appear correctly', () {
      final file = File('lib/domain/constants/elo_constants.dart');
      final content = file.readAsStringSync();
      expect(content, contains('kEloMinRating = 100'));
      expect(content, contains('kEloMaxRating = 500'));
      expect(content, contains('kEloDefaultInitialRating = 400'));
      expect(content, contains('kEloLegacyInitialRating = 500'));
      expect(content, contains('kEloDefaultKFactor = 20'));
    });
  });
}
