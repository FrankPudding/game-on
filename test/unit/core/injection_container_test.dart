import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:game_on/core/config.dart';
import 'package:game_on/core/injection_container.dart';
import 'package:game_on/data/services/hive/hive_database_migration_service.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/application/services/create_league_service.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/application/services/update_user_service.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/users_provider.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.appDir);
  final Directory appDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => appDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPlatform;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    originalPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    await GetIt.instance.reset();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    PathProviderPlatform.instance = originalPlatform;
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('initInjection', () {
    test('should register config and all dependencies', () async {
      await initInjection(AppConfig());

      expect(sl<AppConfig>().dataSourceType, DataSourceType.hive);
      expect(sl<AppConfig>().hiveDbVersion, 1);

      expect(sl.isRegistered<LeagueRepository>(), isTrue);
      expect(sl.isRegistered<LeaguePlayerRepository>(), isTrue);
      expect(sl.isRegistered<UserRepository>(), isTrue);
      expect(sl.isRegistered<SimpleMatchRepository>(), isTrue);
      expect(sl.isRegistered<RankingPolicyRepository>(), isTrue);
      expect(sl.isRegistered<CreateLeagueService>(), isTrue);
      expect(sl.isRegistered<DeleteUserService>(), isTrue);
      expect(sl.isRegistered<UpdateUserService>(), isTrue);
      expect(sl.isRegistered<HiveDatabaseMigrationService>(), isTrue);
    });

    test('should be idempotent when called twice', () async {
      await initInjection(AppConfig());
      await initInjection(AppConfig());

      expect(sl.isRegistered<LeagueRepository>(), isTrue);
      expect(sl.isRegistered<UserRepository>(), isTrue);
      expect(sl.isRegistered<CreateLeagueService>(), isTrue);
    });

    test('should resolve all registered dependencies', () async {
      await initInjection(AppConfig());

      expect(sl<LeagueRepository>(), isNotNull);
      expect(sl<LeaguePlayerRepository>(), isNotNull);
      expect(sl<UserRepository>(), isNotNull);
      expect(sl<SimpleMatchRepository>(), isNotNull);
      expect(sl<RankingPolicyRepository>(), isNotNull);
      expect(sl<CreateLeagueService>(), isNotNull);
      expect(sl<DeleteUserService>(), isNotNull);
      expect(sl<UpdateUserService>(), isNotNull);
      expect(sl<HiveDatabaseMigrationService>(), isNotNull);
    });

    test('should respect configured db version', () async {
      await initInjection(AppConfig(hiveDbVersion: 5));

      final meta = await Hive.openBox<dynamic>('meta');
      expect(meta.get('db_version'), 5);
      await meta.close();
    });

    test('should throw for unsupported data source type', () async {
      expect(
        () => initInjection(AppConfig(dataSourceType: DataSourceType.mock)),
        throwsUnimplementedError,
      );
    });

    test('provider getters should resolve from the service locator', () async {
      await initInjection(AppConfig());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(leagueRepositoryProvider), isNotNull);
      expect(container.read(rankingPolicyRepositoryProvider), isNotNull);
      expect(container.read(createLeagueServiceProvider), isNotNull);
      expect(container.read(userRepositoryProvider), isNotNull);
      expect(container.read(deleteUserServiceProvider), isNotNull);
      expect(container.read(updateUserServiceProvider), isNotNull);
    });
  });
}
