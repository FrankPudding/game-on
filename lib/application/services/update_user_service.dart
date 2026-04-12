import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user.dart';

class UpdateUserService {
  UpdateUserService(
    this._userRepository,
  );

  final UserRepository _userRepository;

  Future<void> execute(User updatedUser) async {
    // 1. Update the user in the repository
    await _userRepository.put(updatedUser);
  }
}
