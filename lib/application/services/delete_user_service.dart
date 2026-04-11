import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/league_player_repository.dart';
import '../../domain/repositories/match/simple_match_repository.dart';

class DeleteUserService {
  DeleteUserService(
    this._userRepository,
    this._playerRepository,
    this._matchRepository,
  );

  final UserRepository _userRepository;
  final LeaguePlayerRepository _playerRepository;
  final SimpleMatchRepository _matchRepository;

  Future<void> execute(String userId) async {
    // 1. Find all league players associated with this user
    // We use getAll() and filter manually to be absolutely sure we don't miss anything
    final allPlayers = await _playerRepository.getAll();
    final userPlayers = allPlayers.where((p) => p.userId == userId).toList();
    final playerIds = userPlayers.map((p) => p.id).toSet();

    // 2. Find and delete matches for each player
    // We delete the match if ANY of the user's players are involved.
    final allMatches = await _matchRepository.getAll();

    for (final match in allMatches) {
      final involvesUser = match.sides.any(
        (side) => side.playerIds.any((pid) => playerIds.contains(pid)),
      );
      if (involvesUser) {
        await _matchRepository.delete(match.id);
      }
    }

    // 3. Delete league players
    for (final player in userPlayers) {
      await _playerRepository.delete(player.id);
    }

    // 4. Delete the user
    await _userRepository.delete(userId);
  }
}
