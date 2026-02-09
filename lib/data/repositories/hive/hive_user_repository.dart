import 'package:hive/hive.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../models/hive/user_hive_model.dart';

class HiveUserRepository implements UserRepository {
  HiveUserRepository(this._box);
  final Box<UserHiveModel> _box;

  @override
  Future<User?> get(String id) async {
    final model = _box.get(id);
    return model?.toDomain();
  }

  @override
  Future<List<User>> getAll() async {
    return _box.values.map((model) => model.toDomain()).toList();
  }

  @override
  Future<void> put(User item) async {
    final model = UserHiveModel.fromDomain(item);
    await _box.put(model.id, model);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
