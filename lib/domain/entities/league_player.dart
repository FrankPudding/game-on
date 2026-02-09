class LeaguePlayer {
  final String id;
  final String userId;
  final String leagueId;
  final String name;
  final String? icon;
  final String avatarColorHex;

  LeaguePlayer({
    required this.id,
    required this.userId,
    required this.leagueId,
    required this.name,
    required this.avatarColorHex,
    this.icon,
  });

  LeaguePlayer copyWith({
    String? id,
    String? userId,
    String? leagueId,
    String? name,
    String? icon,
    String? avatarColorHex,
  }) {
    return LeaguePlayer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      leagueId: leagueId ?? this.leagueId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
    );
  }
}
