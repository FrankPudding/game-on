import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'first_to_state.g.dart';

@HiveType(typeId: 10)
@JsonSerializable()
class FirstToState extends HiveObject {
  @HiveField(0)
  final String matchId;

  @HiveField(1)
  final String teamId;

  @HiveField(2)
  final int currentScore;

  FirstToState({
    required this.matchId,
    required this.teamId,
    this.currentScore = 0,
  });

  factory FirstToState.fromJson(Map<String, dynamic> json) =>
      _$FirstToStateFromJson(json);
  Map<String, dynamic> toJson() => _$FirstToStateToJson(this);
}
