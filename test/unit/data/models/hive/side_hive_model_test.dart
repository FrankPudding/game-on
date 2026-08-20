import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/data/models/hive/side_hive_model.dart';
import 'package:game_on/domain/entities/side.dart';

void main() {
  group('SideHiveModel', () {
    test('fromDomain should map playerIds', () {
      final side = Side(id: 's1', playerIds: ['p1', 'p2']);

      final model = SideHiveModel.fromDomain(side);

      expect(model.id, 's1');
      expect(model.playerIds, ['p1', 'p2']);
    });

    test('toDomain should map all fields', () {
      final model = SideHiveModel(id: 's1', playerIds: ['p1']);

      final side = model.toDomain();

      expect(side.id, 's1');
      expect(side.playerIds, ['p1']);
    });

    test('toDomain should default playerIds to empty when null', () {
      final model = SideHiveModel(id: 's1');

      final side = model.toDomain();

      expect(side.playerIds, isEmpty);
    });
  });
}
