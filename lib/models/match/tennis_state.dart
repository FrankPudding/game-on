import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tennis_state.g.dart';

@HiveType(typeId: 19)
@JsonSerializable()
class TennisState extends HiveObject {
  @HiveField(0)
  final String matchId;

  @HiveField(1)
  final String teamId;

  @HiveField(2)
  final int setsWon;

  @HiveField(3)
  final int currentSetGames;

  @HiveField(4)
  final int currentGamePoints; // 0=0, 1=15, 2=30, 3=40, 4=AD

  @HiveField(5)
  final int? tiebreakPoints;

  TennisState({
    required this.matchId,
    required this.teamId,
    this.setsWon = 0,
    this.currentSetGames = 0,
    this.currentGamePoints = 0,
    this.tiebreakPoints,
  });

  factory TennisState.fromJson(Map<String, dynamic> json) =>
      _$TennisStateFromJson(json);
  Map<String, dynamic> toJson() => _$TennisStateToJson(this);
}
