import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../data/models/hive/user_hive_model.dart';
import '../data/models/hive/league_hive_model.dart';
import '../data/models/hive/league_player_hive_model.dart';
import '../data/models/hive/ranking_policies/simple_ranking_policy_hive_model.dart';

import '../data/models/hive/matches/simple_match_hive_model.dart';
import '../data/models/hive/side_hive_model.dart';
import '../data/repositories/hive/hive_league_repository.dart';
import '../data/repositories/hive/hive_league_player_repository.dart';
import '../data/repositories/hive/matches/hive_simple_match_repository.dart';
import '../data/repositories/hive/hive_user_repository.dart';
import '../domain/repositories/league_repository.dart';
import '../domain/repositories/league_player_repository.dart';
import '../domain/repositories/match/simple_match_repository.dart';
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
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(LeagueHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LeaguePlayerHiveModelAdapter());
  }

  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(SimpleMatchHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(SideHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(SimpleRankingPolicyHiveModelAdapter());
  }

  // Open Boxes
  final userBox = await Hive.openBox<UserHiveModel>('users');
  final leagueBox = await Hive.openBox<LeagueHiveModel>('leagues');
  final leaguePlayerBox =
      await Hive.openBox<LeaguePlayerHiveModel>('league_players');
  final simpleMatchBox =
      await Hive.openBox<SimpleMatchHiveModel>('simple_matches');

  // 2. Register Repositories
  if (!sl.isRegistered<LeagueRepository>()) {
    sl.registerLazySingleton<LeagueRepository>(() => HiveLeagueRepository(
          leagueBox,
        ));
  }

  if (!sl.isRegistered<LeaguePlayerRepository>()) {
    sl.registerLazySingleton<LeaguePlayerRepository>(
        () => HiveLeaguePlayerRepository(leaguePlayerBox));
  }

  if (!sl.isRegistered<UserRepository>()) {
    sl.registerLazySingleton<UserRepository>(() => HiveUserRepository(userBox));
  }

  if (!sl.isRegistered<SimpleMatchRepository>()) {
    sl.registerLazySingleton<SimpleMatchRepository>(
        () => HiveSimpleMatchRepository(
              simpleMatchBox,
            ));
  }
}
