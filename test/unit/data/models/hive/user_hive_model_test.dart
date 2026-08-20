import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/data/models/hive/user_hive_model.dart';
import 'package:game_on/domain/entities/user.dart';

void main() {
  group('UserHiveModel', () {
    test('fromDomain should map all fields', () {
      final user = User(
        id: 'u1',
        name: 'Alice',
        avatarColorHex: 'AE0C00',
        icon: '🥇',
      );

      final model = UserHiveModel.fromDomain(user);

      expect(model.id, 'u1');
      expect(model.name, 'Alice');
      expect(model.avatarColorHex, 'AE0C00');
      expect(model.icon, '🥇');
    });

    test('toDomain should map all fields', () {
      final model = UserHiveModel(
        id: 'u1',
        name: 'Alice',
        avatarColorHex: 'AE0C00',
        icon: '🥇',
      );

      final user = model.toDomain();

      expect(user.id, 'u1');
      expect(user.name, 'Alice');
      expect(user.avatarColorHex, 'AE0C00');
      expect(user.icon, '🥇');
    });

    test('toDomain should handle null icon', () {
      final model = UserHiveModel(
        id: 'u2',
        name: 'Bob',
        avatarColorHex: '000000',
      );

      final user = model.toDomain();

      expect(user.icon, isNull);
    });
  });
}
