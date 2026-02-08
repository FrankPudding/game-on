import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'match_participant.g.dart';

@HiveType(typeId: 5)
@JsonSerializable()
class MatchParticipant extends HiveObject {
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

  MatchParticipant({
    required this.id,
    required this.playerId,
    required this.matchId,
    this.score,
    this.isWinner,
    this.pointsEarned,
  });

  factory MatchParticipant.fromJson(Map<String, dynamic> json) =>
      _$MatchParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$MatchParticipantToJson(this);

  MatchParticipant copyWith({
    String? id,
    String? playerId,
    String? matchId,
    int? score,
    bool? isWinner,
    int? pointsEarned,
  }) {
    return MatchParticipant(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      matchId: matchId ?? this.matchId,
      score: score ?? this.score,
      isWinner: isWinner ?? this.isWinner,
      pointsEarned: pointsEarned ?? this.pointsEarned,
    );
  }
}
