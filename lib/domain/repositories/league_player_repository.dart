import '../entities/league_player.dart';
import '../repository.dart';

abstract class LeaguePlayerRepository extends Repository<LeaguePlayer, String> {
  Future<List<LeaguePlayer>> getByLeague(String leagueId);
}
