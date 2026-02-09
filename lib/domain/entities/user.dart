class User {
  final String id;
  final String name;
  final String avatarColorHex;
  final String? icon;

  User({
    required this.id,
    required this.name,
    required this.avatarColorHex,
    this.icon,
  });

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
