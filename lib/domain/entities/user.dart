class User {
  final String id;
  final String name;
  final String avatarColorHex;

  User({
    required this.id,
    required this.name,
    required this.avatarColorHex,
  });

  User copyWith({
    String? id,
    String? name,
    String? avatarColorHex,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
    );
  }
}
