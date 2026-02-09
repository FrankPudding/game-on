import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/user_repository.dart';
import '../core/injection_container.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return sl<UserRepository>();
});

final usersProvider = AsyncNotifierProvider<UsersNotifier, List<User>>(() {
  return UsersNotifier();
});

class UsersNotifier extends AsyncNotifier<List<User>> {
  late final UserRepository _repo;

  @override
  Future<List<User>> build() async {
    _repo = ref.read(userRepositoryProvider);
    return _repo.getAll();
  }

  Future<void> addUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.put(user);
      return _repo.getAll();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getAll());
  }
}
