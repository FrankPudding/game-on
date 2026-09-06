import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/repositories/league_player_repository.dart';
import '../application/services/delete_user_service.dart';
import '../application/services/update_user_service.dart';
import '../core/injection_container.dart';
import 'leagues_provider.dart';
import 'league_detail_provider.dart';
import 'user_detail_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return sl<UserRepository>();
});

final deleteUserServiceProvider = Provider<DeleteUserService>((ref) {
  return sl<DeleteUserService>();
});

final updateUserServiceProvider = Provider<UpdateUserService>((ref) {
  return sl<UpdateUserService>();
});

final usersProvider = AsyncNotifierProvider<UsersNotifier, List<User>>(() {
  return UsersNotifier();
});

class UsersNotifier extends AsyncNotifier<List<User>> {
  late final UserRepository _repo;
  late final DeleteUserService _deleteService;
  late final UpdateUserService _updateService;
  late final LeaguePlayerRepository _playerRepo;

  @override
  Future<List<User>> build() async {
    _repo = ref.read(userRepositoryProvider);
    _deleteService = ref.read(deleteUserServiceProvider);
    _updateService = ref.read(updateUserServiceProvider);
    _playerRepo = ref.read(leaguePlayerRepositoryProvider);
    return _repo.getAll();
  }

  Future<void> addUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.put(user);

      // No self-invalidation - explicit fetch updates our state

      return _repo.getAll();
    });
  }

  Future<void> deleteUser(String userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Use updated service that returns affected league IDs
      final result = await _deleteService.execute(userId);

      // Invalidate dependent providers
      ref.invalidate(leaguesProvider);
      ref.invalidate(userDetailProvider(userId));
      for (final leagueId in result.affectedLeagueIds) {
        ref.invalidate(leagueDetailProvider(leagueId));
      }

      return _repo.getAll();
    });
  }

  Future<void> updateUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _updateService.execute(user);

      // Find leagues where this user has players
      final userPlayers = await _playerRepo.getByUserId(user.id);
      final leagueIds = userPlayers.map((p) => p.leagueId).toSet();

      // Invalidate dependent providers
      ref.invalidate(leaguesProvider);
      ref.invalidate(userDetailProvider(user.id));
      for (final leagueId in leagueIds) {
        ref.invalidate(leagueDetailProvider(leagueId));
      }

      return _repo.getAll();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getAll());
  }
}