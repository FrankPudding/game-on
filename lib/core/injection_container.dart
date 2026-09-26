import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:synchronized/synchronized.dart';
import '../hive_registrar.g.dart';
import '../data/models/hive/user_hive_model.dart';
import '../data/models/hive/league_hive_model.dart';
import '../data/models/hive/league_player_hive_model.dart';
import '../data/models/hive/matches/simple_match_hive_model.dart';
import '../data/models/hive/ranking_policy_hive_model.dart';
import '../data/models/hive/category_hive_model.dart';
import '../data/repositories/hive/hive_league_repository.dart';
import '../data/repositories/hive/hive_league_player_repository.dart';
import '../data/repositories/hive/matches/hive_simple_match_repository.dart';
import '../data/repositories/hive/hive_user_repository.dart';
import '../data/repositories/hive/hive_ranking_policy_repository.dart';
import '../data/repositories/hive/hive_category_repository.dart';
import '../domain/repositories/league_repository.dart';
import '../domain/repositories/league_player_repository.dart';
import '../domain/repositories/match/simple_match_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/repositories/ranking_policy_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../application/services/create_league_service.dart';
import '../application/services/delete_user_service.dart';
import '../application/services/update_user_service.dart';
import '../data/repositories/hive/hive_sort_preference_repository.dart';
import '../domain/repositories/preferences/sort_preference_repository.dart';
import '../data/services/hive/hive_database_migration_service.dart';
import '../data/services/hive/category_index_rebuilder.dart';
import 'config.dart';
import 'constants/hive_box_names.dart';

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
  // Ordered init: Hive.initFlutter already called -> registerAdapters single source -> migrate -> openBox -> rebuild
  // Single source via HiveRegistrar.registerAdapters() with idempotence wrapper (per typeId guards)
  if (!Hive.isAdapterRegistered(0) ||
      !Hive.isAdapterRegistered(1) ||
      !Hive.isAdapterRegistered(3) ||
      !Hive.isAdapterRegistered(6) ||
      !Hive.isAdapterRegistered(8) ||
      !Hive.isAdapterRegistered(9) ||
      !Hive.isAdapterRegistered(10) ||
      !Hive.isAdapterRegistered(11) ||
      !Hive.isAdapterRegistered(12)) {
    try {
      Hive.registerAdapters();
    } catch (e) {
      // Idempotent wrapper: ignore already-registered race
      if (!e.toString().contains('already')) rethrow;
    }
  }

  // Shared Lock singleton via GetIt
  if (!sl.isRegistered<Lock>()) {
    sl.registerSingleton<Lock>(Lock());
  }
  final sharedLock = sl<Lock>();

  // Run Migrations target 2 before openBox
  final migrationService = HiveDatabaseMigrationService();
  await migrationService.migrate(sl<AppConfig>().hiveDbVersion);

  // Open Boxes (ordered, reuse if already opened by migration)
  Future<Box<T>> openOrGet<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return await Hive.openBox<T>(name);
  }

  final userBox = await openOrGet<UserHiveModel>(HiveBoxNames.users);
  final leagueBox = await openOrGet<LeagueHiveModel>(HiveBoxNames.leagues);
  final leaguePlayerBox =
      await openOrGet<LeaguePlayerHiveModel>(HiveBoxNames.leaguePlayers);
  final leaguePlayerUniqueIndexBox =
      await openOrGet<String>(HiveBoxNames.leaguePlayersUniqueIndex);
  final simpleMatchBox =
      await openOrGet<SimpleMatchHiveModel>(HiveBoxNames.simpleMatches);
  final rankingPolicyBox =
      await openOrGet<RankingPolicyHiveModel>(HiveBoxNames.rankingPolicies);
  final categoriesBox =
      await openOrGet<CategoryHiveModel>(HiveBoxNames.categories);
  final categorySlugIndexBox =
      await openOrGet<String>(HiveBoxNames.categorySlugIndex);
  final categoryParentIndexBox =
      await openOrGet<String>(HiveBoxNames.categoryParentIndex);
  final categoryPolicyIndexBox =
      await openOrGet<String>(HiveBoxNames.categoryPolicyIndex);

  // rebuildIfNeeded after openBox drift check
  final rebuilder = CategoryIndexRebuilder();
  await rebuilder.rebuildIfNeeded();

  final Box<String> appPreferencesBox;
  if (Hive.isBoxOpen(HiveSortPreferenceRepository.boxName)) {
    appPreferencesBox = Hive.box<String>(HiveSortPreferenceRepository.boxName);
  } else {
    appPreferencesBox =
        await Hive.openBox<String>(HiveSortPreferenceRepository.boxName);
  }
  if (!sl.isRegistered<SortPreferenceRepository>()) {
    sl.registerLazySingleton<SortPreferenceRepository>(
      () => HiveSortPreferenceRepository(appPreferencesBox),
    );
  }

  // 2. Register Repositories
  if (!sl.isRegistered<LeagueRepository>()) {
    sl.registerLazySingleton<LeagueRepository>(() => HiveLeagueRepository(
          leagueBox,
        ));
  }

  if (!sl.isRegistered<LeaguePlayerRepository>()) {
    sl.registerLazySingleton<LeaguePlayerRepository>(() =>
        HiveLeaguePlayerRepository(
            leaguePlayerBox, leaguePlayerUniqueIndexBox));
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

  if (!sl.isRegistered<CategoryRepository>()) {
    sl.registerLazySingleton<CategoryRepository>(() => HiveCategoryRepository(
          categoriesBox,
          categorySlugIndexBox,
          categoryParentIndexBox,
          rankingPolicyBox,
          sharedLock,
          categoryPolicyIndexBox: categoryPolicyIndexBox,
        ));
  }

  if (!sl.isRegistered<RankingPolicyRepository>()) {
    sl.registerLazySingleton<RankingPolicyRepository>(
        () => HiveRankingPolicyRepository(
              rankingPolicyBox,
              categoryRepository: sl<CategoryRepository>(),
              lock: sharedLock,
              categoryPolicyIndexBox: categoryPolicyIndexBox,
            ));
  }

  // 3. Register Services
  if (!sl.isRegistered<CreateLeagueService>()) {
    sl.registerLazySingleton<CreateLeagueService>(
      () => CreateLeagueService(
        sl<LeagueRepository>(),
        sl<RankingPolicyRepository>(),
        sl<CategoryRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<DeleteUserService>()) {
    sl.registerLazySingleton<DeleteUserService>(
      () => DeleteUserService(
        sl<UserRepository>(),
        sl<LeaguePlayerRepository>(),
        sl<SimpleMatchRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<UpdateUserService>()) {
    sl.registerLazySingleton<UpdateUserService>(
      () => UpdateUserService(
        sl<UserRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<HiveDatabaseMigrationService>()) {
    sl.registerLazySingleton<HiveDatabaseMigrationService>(
        () => HiveDatabaseMigrationService());
  }
}
