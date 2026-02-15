import 'package:game_on/domain/entities/match.dart';
import 'package:game_on/domain/entities/side.dart';

class SimpleMatch extends Match {
  SimpleMatch({
    required super.id,
    required super.leagueId,
    required super.playedAt,
    required super.isComplete,
    required super.sides,
    this.isDraw = false,
    this.winnerSideId,
  });

  final bool isDraw;
  final String? winnerSideId;

  SimpleMatch copyWith({
    String? id,
    String? leagueId,
    DateTime? playedAt,
    bool? isComplete,
    List<Side>? sides,
    bool? isDraw,
    String? winnerSideId,
  }) {
    return SimpleMatch(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      playedAt: playedAt ?? this.playedAt,
      isComplete: isComplete ?? this.isComplete,
      sides: sides ?? this.sides,
      isDraw: isDraw ?? this.isDraw,
      winnerSideId: winnerSideId ?? this.winnerSideId,
    );
  }
}
