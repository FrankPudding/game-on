class Side {
  Side({
    required this.id,
    required this.playerIds,
  });

  final String id;
  final List<String> playerIds;

  Side copyWith({
    String? id,
    List<String>? playerIds,
  }) {
    return Side(
      id: id ?? this.id,
      playerIds: playerIds ?? this.playerIds,
    );
  }
}
