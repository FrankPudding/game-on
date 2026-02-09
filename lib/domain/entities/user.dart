class User {
  User({
    required this.id,
    required this.name,
    required this.avatarColorHex,
    this.icon,
  });
  final String id;
  final String name;
  final String avatarColorHex;
  final String? icon;

  User copyWith({
    String? id,
    String? name,
    String? avatarColorHex,
    String? icon,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
      icon: icon ?? this.icon,
    );
  }
}
