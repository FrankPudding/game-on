import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/user.dart';

void main() {
  group('User', () {
    final tUser = User(
      id: 'u1',
      name: 'Alice',
      avatarColorHex: 'AE0C00',
      icon: '🥇',
    );

    test('should create User with provided values', () {
      expect(tUser.id, 'u1');
      expect(tUser.name, 'Alice');
      expect(tUser.avatarColorHex, 'AE0C00');
      expect(tUser.icon, '🥇');
    });

    test('icon should default to null', () {
      final user = User(id: 'u2', name: 'Bob', avatarColorHex: '000000');
      expect(user.icon, isNull);
    });

    test('copyWith should return a new object with updated values', () {
      final updated = tUser.copyWith(name: 'Alicia', icon: '🥈');

      expect(updated.id, tUser.id);
      expect(updated.avatarColorHex, tUser.avatarColorHex);
      expect(updated.name, 'Alicia');
      expect(updated.icon, '🥈');
      expect(identical(updated, tUser), isFalse);
    });

    test('copyWith without args should preserve all values', () {
      final updated = tUser.copyWith();
      expect(updated.id, tUser.id);
      expect(updated.name, tUser.name);
      expect(updated.avatarColorHex, tUser.avatarColorHex);
      expect(updated.icon, tUser.icon);
    });
  });
}
