import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'frames_match.g.dart';

@HiveType(typeId: 15)
@JsonSerializable()
class FramesMatch extends HiveObject {
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

  FramesMatch({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    this.isComplete = false,
    this.winnerTeamId,
  });

  factory FramesMatch.fromJson(Map<String, dynamic> json) =>
      _$FramesMatchFromJson(json);
  Map<String, dynamic> toJson() => _$FramesMatchToJson(this);
}
