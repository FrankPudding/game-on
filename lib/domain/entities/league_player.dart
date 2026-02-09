class LeaguePlayer {
  final String id;
  final String playerId;
  final String leagueId;
  final String name;
  final String? icon;
  final String avatarColorHex;

  LeaguePlayer({
    required this.id,
    required this.playerId,
    required this.leagueId,
    required this.name,
    required this.avatarColorHex,
    this.icon,
  });

  LeaguePlayer copyWith({
    String? id,
    String? playerId,
    String? leagueId,
    String? name,
    String? icon,
    String? avatarColorHex,
  }) {
    return LeaguePlayer(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      leagueId: leagueId ?? this.leagueId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
    );
  }
}
