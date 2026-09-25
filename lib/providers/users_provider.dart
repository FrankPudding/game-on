import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/sorting/name_sort.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/repositories/league_player_repository.dart';
import '../application/services/delete_user_service.dart';
import '../application/services/update_user_service.dart';
import '../core/injection_container.dart';
import 'leagues_provider.dart';
import 'league_detail_provider.dart';
import 'user_detail_provider.dart';
// TODO(skeleton): sortedLeaguesProvider invalidation not owned by usersProvider
// Users mutations already invalidate leaguesProvider which transitively may require
// sortedLeaguesProvider refresh — documented in AGENTS.md boundary.

void _sortUsers(List<User> users) {
  users.sort((a, b) {
    final c = compareNames(a.name, b.name);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });
}

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
  late UserRepository _repo;
  late DeleteUserService _deleteService;
  late UpdateUserService _updateService;
  late LeaguePlayerRepository _playerRepo;

  @override
  Future<List<User>> build() async {
    _repo = ref.read(userRepositoryProvider);
    _deleteService = ref.read(deleteUserServiceProvider);
    _updateService = ref.read(updateUserServiceProvider);
    _playerRepo = ref.read(leaguePlayerRepositoryProvider);
    final users = await _repo.getAll();
    _sortUsers(users);
    return users;
  }

  Future<void> addUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.put(user);

      // No self-invalidation - explicit fetch updates our state

      final users = await _repo.getAll();
      _sortUsers(users);
      return users;
    });
    if (state.hasError && state.error != null) {
      throw state.error!;
    }
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

      final users = await _repo.getAll();
      _sortUsers(users);
      return users;
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

      final users = await _repo.getAll();
      _sortUsers(users);
      return users;
    });
    if (state.hasError && state.error != null) {
      throw state.error!;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final users = await _repo.getAll();
      _sortUsers(users);
      return users;
    });
  }
}
