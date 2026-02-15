import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/matches/simple_match.dart';
import '../side_hive_model.dart';

part 'simple_match_hive_model.g.dart';

@HiveType(typeId: 6)
class SimpleMatchHiveModel extends HiveObject {
  SimpleMatchHiveModel({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    required this.isComplete,
    required this.isDraw,
    this.sides,
    this.winnerSideId,
  });

  factory SimpleMatchHiveModel.fromDomain(SimpleMatch match) {
    return SimpleMatchHiveModel(
      id: match.id,
      leagueId: match.leagueId,
      playedAt: match.playedAt,
      isComplete: match.isComplete,
      isDraw: match.isDraw,
      sides: match.sides.map((s) => SideHiveModel.fromDomain(s)).toList(),
      winnerSideId: match.winnerSideId,
    );
  }
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String leagueId;

  @HiveField(2)
  final DateTime playedAt;

  @HiveField(3)
  final bool isComplete;

  @HiveField(4)
  final bool isDraw;

  @HiveField(5)
  final String? winnerSideId;

  @HiveField(6)
  final List<SideHiveModel>? sides;

  SimpleMatch toDomain() {
    return SimpleMatch(
      id: id,
      leagueId: leagueId,
      playedAt: playedAt,
      isComplete: isComplete,
      isDraw: isDraw,
      sides: (sides ?? []).map((s) => s.toDomain()).toList(),
      winnerSideId: winnerSideId,
    );
  }
}
