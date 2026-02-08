import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tennis_match.g.dart';

@HiveType(typeId: 18)
@JsonSerializable()
class TennisMatch extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String leagueId;

  @HiveField(2)
  final DateTime playedAt;

  @HiveField(3)
  final bool isComplete;

  @HiveField(4)
  final String? winnerTeamId;

  TennisMatch({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    this.isComplete = false,
    this.winnerTeamId,
  });

  factory TennisMatch.fromJson(Map<String, dynamic> json) =>
      _$TennisMatchFromJson(json);
  Map<String, dynamic> toJson() => _$TennisMatchToJson(this);
}
