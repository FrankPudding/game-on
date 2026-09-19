import '../entities/league_player.dart';
import '../repository.dart';
import '../exceptions/duplicate_league_player_exception.dart';

abstract class LeaguePlayerRepository extends Repository<LeaguePlayer, String> {
  Future<List<LeaguePlayer>> getByLeague(String leagueId);
  Future<List<LeaguePlayer>> getByUserId(String userId);

  /// Adds a player only if no player with the same userId exists in the same league.
  /// Throws [DuplicateLeaguePlayerException] if a player with the same userId
  /// already exists in the league.
  Future<LeaguePlayer> addPlayerIfUnique({
    required String userId,
    required String leagueId,
    required String name,
    required String avatarColorHex,
    String? icon,
  });
}
