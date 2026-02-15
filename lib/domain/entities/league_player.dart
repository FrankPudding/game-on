class LeaguePlayer {
  LeaguePlayer({
    required this.id,
    required this.userId,
    required this.leagueId,
    required this.name,
    required this.avatarColorHex,
    this.icon,
  });
  final String id;
  final String userId;
  final String leagueId;
  final String name;
  final String? icon;
  final String avatarColorHex;
}
