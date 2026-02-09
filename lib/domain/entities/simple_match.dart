class SimpleMatch {
  SimpleMatch({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    required this.isComplete,
    this.isDraw = false,
    this.winnerId,
  });
  final String id;
  final String leagueId;
  final DateTime playedAt;
  final bool isComplete;
  final bool isDraw;
  final String? winnerId;

  SimpleMatch copyWith({
    String? id,
    String? leagueId,
    DateTime? playedAt,
    bool? isComplete,
    bool? isDraw,
    String? winnerId,
  }) {
    return SimpleMatch(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      playedAt: playedAt ?? this.playedAt,
      isComplete: isComplete ?? this.isComplete,
      isDraw: isDraw ?? this.isDraw,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
