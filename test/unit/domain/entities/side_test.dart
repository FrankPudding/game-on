import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/side.dart';

void main() {
  group('Side', () {
    final tSide = Side(id: 's1', playerIds: ['p1', 'p2']);

    test('should create Side with provided values', () {
      expect(tSide.id, 's1');
      expect(tSide.playerIds, ['p1', 'p2']);
    });

    test('copyWith should update values', () {
      final updated = tSide.copyWith(playerIds: ['p3']);

      expect(updated.id, tSide.id);
      expect(updated.playerIds, ['p3']);
    });

    test('copyWith without args should preserve all values', () {
      final updated = tSide.copyWith();
      expect(updated.id, tSide.id);
      expect(updated.playerIds, tSide.playerIds);
      expect(identical(updated, tSide), isFalse);
    });
  });
}
