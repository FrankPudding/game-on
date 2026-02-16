class League {
  League({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isArchived;

  League copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return League(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
