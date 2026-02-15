import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/side.dart';

part 'side_hive_model.g.dart';

@HiveType(typeId: 8)
class SideHiveModel {
  SideHiveModel({
    required this.id,
    this.playerIds,
  });

  factory SideHiveModel.fromDomain(Side side) {
    return SideHiveModel(
      id: side.id,
      playerIds: side.playerIds,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(2)
  final List<String>? playerIds;

  Side toDomain() {
    return Side(
      id: id,
      playerIds: playerIds ?? [],
    );
  }
}
