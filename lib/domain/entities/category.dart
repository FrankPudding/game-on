import '../value_objects/slug.dart';
import '../value_objects/category_icon.dart';

const int kCategoryMaxDepth = 1;

class Category {
  Category({
    required this.id,
    required this.name,
    required Slug slug,
    required this.icon,
    this.parentId,
    required this.sortOrder,
    required this.isBuiltIn,
    required this.createdAt,
    required this.updatedAt,
  })  : slug = slug,
        _slugValue = slug.value {
    if (name.trim().isEmpty) {
      throw ArgumentError('Category name must not be empty');
    }
    if (parentId != null && parentId == id) {
      throw ArgumentError('Category parentId must not equal id');
    }
  }

  final String id;
  final String name;
  final Slug slug;
  final String _slugValue;
  String get slugValue => _slugValue;
  final CategoryIcon icon;
  final String? parentId;
  final int sortOrder;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category copyWith({
    String? name,
    Slug? slug,
    CategoryIcon? icon,
    String? parentId,
    int? sortOrder,
    DateTime? updatedAt,
    bool clearParentId = false,
  }) {
    // isBuiltIn immutable - only sortOrder and icon mutable per spec
    // But we allow name/slug/parentId in copyWith for general use; repository guards isBuiltIn
    final newParentId = clearParentId ? null : (parentId ?? this.parentId);
    if (newParentId != null && newParentId == id) {
      throw ArgumentError('Category parentId must not equal id');
    }
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError('Category name must not be empty');
    }
    return Category(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      parentId: newParentId,
      sortOrder: sortOrder ?? this.sortOrder,
      isBuiltIn: isBuiltIn,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Validates that categories do not contain cycles and depth <= maxDepth.
  /// [allCategories] should contain this category plus all others.
  static void validateNoCycleAndDepth(
    List<Category> allCategories, {
    int maxDepth = kCategoryMaxDepth,
  }) {
    final byId = {for (var c in allCategories) c.id: c};

    for (final cat in allCategories) {
      // DFS cycle detection and depth
      final visited = <String>{};
      String? currentId = cat.id;
      int depth = 0;
      while (currentId != null) {
        if (visited.contains(currentId)) {
          throw ArgumentError('Cycle detected involving category $currentId');
        }
        visited.add(currentId);
        final current = byId[currentId];
        if (current == null) break;
        final parent = current.parentId;
        if (parent != null) {
          depth++;
          if (depth > maxDepth) {
            throw ArgumentError(
                'Category depth exceeds max $maxDepth for ${cat.id}');
          }
        }
        currentId = parent;
      }
    }
  }
}
