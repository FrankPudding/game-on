import '../entities/league.dart';
import '../entities/league_player.dart';
import 'repository.dart';

abstract class LeagueRepository extends Repository<League, String> {
  Future<void> archiveLeague(String id);

  Future<void> addPlayer({
    required String leagueId,
    required String name,
  });

  List<LeaguePlayer> getLeaguePlayers(String leagueId);
}
