import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/hive/user_hive_model.dart';
import '../data/models/hive/league_hive_model.dart';
import '../data/models/hive/league_player_hive_model.dart';
import '../data/models/hive/match_participant_hive_model.dart';
import '../data/models/hive/simple_match_hive_model.dart';
import '../data/repositories/hive/hive_league_repository.dart';
import '../data/repositories/hive/hive_simple_match_repository.dart';
import '../data/repositories/hive/hive_user_repository.dart';
import '../domain/repositories/league_repository.dart';
import '../domain/repositories/simple_match_repository.dart';
import '../domain/repositories/user_repository.dart';
import 'config.dart';

final sl = GetIt.instance;
Future<void> initInjection(AppConfig config) async {
  // 1. Register Config
  if (!sl.isRegistered<AppConfig>()) {
    sl.registerSingleton<AppConfig>(config);
  }

  if (config.dataSourceType == DataSourceType.hive) {
    await Hive.initFlutter();
    await _initHive();
  } else {
    throw UnimplementedError(
        'DataSourceType ${config.dataSourceType} not implemented');
  }
}

Future<void> _initHive() async {
  // Register Adapters
  if (!Hive.isAdapterRegistered(0))
    Hive.registerAdapter(UserHiveModelAdapter());
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(LeagueHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LeaguePlayerHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(MatchParticipantHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(SimpleMatchHiveModelAdapter());
  }

  // Open Boxes
  final userBox = await Hive.openBox<UserHiveModel>('users');
  final leagueBox = await Hive.openBox<LeagueHiveModel>('leagues');
  final leaguePlayerBox =
      await Hive.openBox<LeaguePlayerHiveModel>('league_players');
  final matchParticipantBox =
      await Hive.openBox<MatchParticipantHiveModel>('match_participants');
  final simpleMatchBox =
      await Hive.openBox<SimpleMatchHiveModel>('simple_matches');

  // 2. Register Repositories
  if (!sl.isRegistered<LeagueRepository>()) {
    sl.registerLazySingleton<LeagueRepository>(() => HiveLeagueRepository(
          leagueBox,
          userBox,
          leaguePlayerBox,
        ));
  }

  if (!sl.isRegistered<UserRepository>()) {
    sl.registerLazySingleton<UserRepository>(() => HiveUserRepository(userBox));
  }

  if (!sl.isRegistered<SimpleMatchRepository>()) {
    sl.registerLazySingleton<SimpleMatchRepository>(
        () => HiveSimpleMatchRepository(
              simpleMatchBox,
              matchParticipantBox,
            ));
  }
}
