class MatchParticipant {
  MatchParticipant({
    required this.id,
    required this.playerId,
    required this.matchId,
    this.score,
    this.isWinner,
    this.pointsEarned,
  });
  final String id;
  final String playerId;
  final String matchId;
  final int? score;
  final bool? isWinner;
  final int? pointsEarned;

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
