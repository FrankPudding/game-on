import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';
import '../models/league.dart';
import '../models/league_player.dart';
import '../models/match_participant.dart';
import '../models/match_team.dart';
import '../models/configs/simple_config.dart';
import '../models/configs/first_to_config.dart';
import '../models/configs/timed_config.dart';
import '../models/configs/frames_config.dart';
import '../models/configs/tennis_config.dart';
import '../models/match/simple_match.dart';
import '../models/match/first_to_match.dart';
import '../models/match/first_to_state.dart';
import '../models/match/timed_match.dart';
import '../models/match/timed_state.dart';
import '../models/match/frames_match.dart';
import '../models/match/frames_state.dart';
import '../models/match/tennis_match.dart';
import '../models/match/tennis_state.dart';

class DatabaseService {
  static const String boxUsers = 'users';
  static const String boxLeagues = 'leagues';
  static const String boxLeaguePlayers = 'league_players';
  static const String boxSimpleConfigs = 'simple_configs';
  static const String boxSimpleMatches = 'simple_matches';
  static const String boxMatchParticipants = 'match_participants';

  static Future<void> init() async {
    try {
      await Hive.initFlutter();

      // Register Adapters
      Hive.registerAdapter(UserAdapter());
      Hive.registerAdapter(LeagueAdapter());
      Hive.registerAdapter(ScoringSystemAdapter()); // Enum adapter
      Hive.registerAdapter(LeaguePlayerAdapter());
      Hive.registerAdapter(MatchParticipantAdapter());
      Hive.registerAdapter(MatchTeamAdapter()); // 7

      // Configs
      Hive.registerAdapter(SimpleConfigAdapter()); // 4
      Hive.registerAdapter(FirstToConfigAdapter()); // 8
      Hive.registerAdapter(TimedConfigAdapter()); // 11
      Hive.registerAdapter(FramesConfigAdapter()); // 14
      Hive.registerAdapter(TennisConfigAdapter()); // 17

      // Matches & States
      Hive.registerAdapter(SimpleMatchAdapter()); // 6
      Hive.registerAdapter(FirstToMatchAdapter()); // 9
      Hive.registerAdapter(FirstToStateAdapter()); // 10
      Hive.registerAdapter(TimedMatchAdapter()); // 12
      Hive.registerAdapter(TimedStateAdapter()); // 13
      Hive.registerAdapter(FramesMatchAdapter()); // 15
      Hive.registerAdapter(FramesStateAdapter()); // 16
      Hive.registerAdapter(TennisMatchAdapter()); // 18
      Hive.registerAdapter(TennisStateAdapter()); // 19

      // Open Boxes
      print('DEBUG: Opening Hive boxes...');
      await Hive.openBox<User>(boxUsers);
      await Hive.openBox<League>(boxLeagues);
      await Hive.openBox<LeaguePlayer>(boxLeaguePlayers);
      await Hive.openBox<MatchParticipant>(boxMatchParticipants);
      await Hive.openBox<MatchTeam>('match_teams');

      await Hive.openBox<SimpleConfig>(boxSimpleConfigs);
      await Hive.openBox<SimpleMatch>(boxSimpleMatches);

      // Other boxes
      await Hive.openBox<FirstToConfig>('first_to_configs');
      await Hive.openBox<FirstToMatch>('first_to_matches');
      await Hive.openBox<FirstToState>('first_to_states');

      await Hive.openBox<TimedConfig>('timed_configs');
      await Hive.openBox<TimedMatch>('timed_matches');
      await Hive.openBox<TimedState>('timed_states');

      await Hive.openBox<FramesConfig>('frames_configs');
      await Hive.openBox<FramesMatch>('frames_matches');
      await Hive.openBox<FramesState>('frames_states');

      await Hive.openBox<TennisConfig>('tennis_configs');
      await Hive.openBox<TennisMatch>('tennis_matches');
      await Hive.openBox<TennisState>('tennis_states');
      print('DEBUG: All boxes opened.');
    } catch (e) {
      print('ERROR in DatabaseService.init(): $e');
      rethrow;
    }
  }

  // Box Accessors
  static Box<User> get users => Hive.box<User>(boxUsers);
  static Box<League> get leagues => Hive.box<League>(boxLeagues);
  static Box<LeaguePlayer> get leaguePlayers =>
      Hive.box<LeaguePlayer>(boxLeaguePlayers);
  static Box<MatchParticipant> get matchParticipants =>
      Hive.box<MatchParticipant>(boxMatchParticipants);

  // Simple
  static Box<SimpleConfig> get simpleConfigs =>
      Hive.box<SimpleConfig>(boxSimpleConfigs);
  static Box<SimpleMatch> get simpleMatches =>
      Hive.box<SimpleMatch>(boxSimpleMatches);

  // First To
  static Box<FirstToMatch> get firstToMatches =>
      Hive.box<FirstToMatch>('first_to_matches');
  static Box<FirstToConfig> get firstToConfigs =>
      Hive.box<FirstToConfig>('first_to_configs');

  // Timed
  static Box<TimedMatch> get timedMatches =>
      Hive.box<TimedMatch>('timed_matches');
  static Box<TimedConfig> get timedConfigs =>
      Hive.box<TimedConfig>('timed_configs');

  // Frames
  static Box<FramesMatch> get framesMatches =>
      Hive.box<FramesMatch>('frames_matches');
  static Box<FramesConfig> get framesConfigs =>
      Hive.box<FramesConfig>('frames_configs');

  // Tennis
  static Box<TennisMatch> get tennisMatches =>
      Hive.box<TennisMatch>('tennis_matches');
  static Box<TennisConfig> get tennisConfigs =>
      Hive.box<TennisConfig>('tennis_configs');
}
