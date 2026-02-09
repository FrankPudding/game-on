import 'package:hive/hive.dart';
import '../../../../domain/entities/league.dart';

part 'league_hive_model.g.dart';

@HiveType(typeId: 3)
class LeagueHiveModel extends HiveObject {
  LeagueHiveModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isArchived,
    required this.pointsForWin,
    required this.pointsForDraw,
    required this.pointsForLoss,
  });

  factory LeagueHiveModel.fromDomain(League league) {
    return LeagueHiveModel(
      id: league.id,
      name: league.name,
      createdAt: league.createdAt,
      isArchived: league.isArchived,
      pointsForWin: league.pointsForWin,
      pointsForDraw: league.pointsForDraw,
      pointsForLoss: league.pointsForLoss,
    );
  }
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final bool isArchived;

  @HiveField(4)
  final int pointsForWin;

  @HiveField(5)
  final int pointsForDraw;

  @HiveField(6)
  final int pointsForLoss;

  League toDomain() {
    return League(
      id: id,
      name: name,
      createdAt: createdAt,
      isArchived: isArchived,
      pointsForWin: pointsForWin,
      pointsForDraw: pointsForDraw,
      pointsForLoss: pointsForLoss,
    );
  }
}
