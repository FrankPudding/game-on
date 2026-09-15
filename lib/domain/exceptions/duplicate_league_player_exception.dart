class DuplicateLeaguePlayerException implements Exception {
  const DuplicateLeaguePlayerException({
    required this.userId,
    required this.leagueId,
  });

  final String userId;
  final String leagueId;

  @override
  String toString() =>
      'DuplicateLeaguePlayerException: User $userId is already a player in league $leagueId';
}