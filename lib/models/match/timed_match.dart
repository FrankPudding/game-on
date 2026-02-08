import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'timed_match.g.dart';

@HiveType(typeId: 12)
@JsonSerializable()
class TimedMatch extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String leagueId;

  @HiveField(2)
  final DateTime playedAt;

  @HiveField(3)
  final bool isComplete;

  TimedMatch({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    this.isComplete = false,
  });

  factory TimedMatch.fromJson(Map<String, dynamic> json) =>
      _$TimedMatchFromJson(json);
  Map<String, dynamic> toJson() => _$TimedMatchToJson(this);
}
