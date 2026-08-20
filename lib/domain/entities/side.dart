class Side {
  Side({
    required this.id,
    required this.playerIds,
    this.score,
  });

  final String id;
  final List<String> playerIds;
  final int? score;

  Side copyWith({
    String? id,
    List<String>? playerIds,
    int? score,
  }) {
    return Side(
      id: id ?? this.id,
      playerIds: playerIds ?? this.playerIds,
      score: score ?? this.score,
    );
  }
}
