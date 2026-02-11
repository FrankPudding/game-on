import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/match_participant.dart';

part 'match_participant_hive_model.g.dart';

@HiveType(typeId: 5)
class MatchParticipantHiveModel extends HiveObject {
  MatchParticipantHiveModel({
    required this.id,
    required this.playerId,
    required this.matchId,
    this.score,
    this.isWinner,
    this.pointsEarned,
  });

  factory MatchParticipantHiveModel.fromDomain(MatchParticipant participant) {
    return MatchParticipantHiveModel(
      id: participant.id,
      playerId: participant.playerId,
      matchId: participant.matchId,
      score: participant.score,
      isWinner: participant.isWinner,
      pointsEarned: participant.pointsEarned,
    );
  }
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String playerId;

  @HiveField(2)
  final String matchId;

  @HiveField(3)
  final int? score;

  @HiveField(4)
  final bool? isWinner;

  @HiveField(5)
  final int? pointsEarned;

  MatchParticipant toDomain() {
    return MatchParticipant(
      id: id,
      playerId: playerId,
      matchId: matchId,
      score: score,
      isWinner: isWinner,
      pointsEarned: pointsEarned,
    );
  }
}
