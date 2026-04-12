import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/user_repository.dart';
import '../application/services/delete_user_service.dart';
import '../application/services/update_user_service.dart';
import '../core/injection_container.dart';

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

  @override
  Future<List<User>> build() async {
    _repo = ref.read(userRepositoryProvider);
    _deleteService = ref.read(deleteUserServiceProvider);
    _updateService = ref.read(updateUserServiceProvider);
    return _repo.getAll();
  }

  Future<void> addUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.put(user);
      return _repo.getAll();
    });
  }

  Future<void> deleteUser(String userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _deleteService.execute(userId);
      return _repo.getAll();
    });
  }

  Future<void> updateUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _updateService.execute(user);
      return _repo.getAll();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getAll());
  }
}
