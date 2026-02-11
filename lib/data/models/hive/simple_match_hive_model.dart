import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/simple_match.dart';

part 'simple_match_hive_model.g.dart';

@HiveType(typeId: 6)
class SimpleMatchHiveModel extends HiveObject {
  SimpleMatchHiveModel({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    required this.isComplete,
    required this.isDraw,
    this.winnerId,
  });

  factory SimpleMatchHiveModel.fromDomain(SimpleMatch match) {
    return SimpleMatchHiveModel(
      id: match.id,
      leagueId: match.leagueId,
      playedAt: match.playedAt,
      isComplete: match.isComplete,
      isDraw: match.isDraw,
      winnerId: match.winnerId,
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
  final String? winnerId;

  SimpleMatch toDomain() {
    return SimpleMatch(
      id: id,
      leagueId: leagueId,
      playedAt: playedAt,
      isComplete: isComplete,
      isDraw: isDraw,
      winnerId: winnerId,
    );
  }
}
