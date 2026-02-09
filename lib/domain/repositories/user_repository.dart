import '../entities/user.dart';
import 'repository.dart';

abstract class UserRepository extends Repository<User, String> {
  // Add any user-specific methods here if needed in the future
}
