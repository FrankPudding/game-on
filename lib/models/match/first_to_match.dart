import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'first_to_match.g.dart';

@HiveType(typeId: 9)
@JsonSerializable()
class FirstToMatch extends HiveObject {
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

  FirstToMatch({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    this.isComplete = false,
    this.winnerTeamId,
  });

  factory FirstToMatch.fromJson(Map<String, dynamic> json) =>
      _$FirstToMatchFromJson(json);
  Map<String, dynamic> toJson() => _$FirstToMatchToJson(this);
}
