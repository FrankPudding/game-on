import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/league.dart';

part 'league_hive_model.g.dart';

@HiveType(typeId: 3)
class LeagueHiveModel extends HiveObject {
  LeagueHiveModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isArchived,
  });

  factory LeagueHiveModel.fromDomain(League league) {
    return LeagueHiveModel(
      id: league.id,
      name: league.name,
      createdAt: league.createdAt,
      isArchived: league.isArchived,
    );
  }
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(4)
  final bool isArchived;

  League toDomain() {
    return League(
      id: id,
      name: name,
      createdAt: createdAt,
      isArchived: isArchived,
    );
  }
}
