import 'package:hive/hive.dart';
import '../../../../domain/entities/user.dart';

part 'user_hive_model.g.dart';

@HiveType(typeId: 0)
class UserHiveModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String avatarColorHex;

  @HiveField(3)
  final String? icon;

  UserHiveModel({
    required this.id,
    required this.name,
    required this.avatarColorHex,
    this.icon,
  });

  factory UserHiveModel.fromDomain(User user) {
    return UserHiveModel(
      id: user.id,
      name: user.name,
      avatarColorHex: user.avatarColorHex,
      icon: user.icon,
    );
  }

  User toDomain() {
    return User(
      id: id,
      name: name,
      avatarColorHex: avatarColorHex,
      icon: icon,
    );
  }
}
