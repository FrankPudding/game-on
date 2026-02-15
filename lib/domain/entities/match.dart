import 'package:game_on/domain/entities/side.dart';

abstract class Match {
  Match({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    required this.isComplete,
    required this.sides,
  });

  final String id;
  final String leagueId;
  final DateTime playedAt;
  final bool isComplete;
  final List<Side> sides;
}
