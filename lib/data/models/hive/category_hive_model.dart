import 'package:hive_ce/hive_ce.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/value_objects/category_icon.dart';
import '../../../domain/value_objects/slug.dart';

part 'category_hive_model.g.dart';

@HiveType(typeId: 11)
class CategoryHiveModel extends HiveObject {
  CategoryHiveModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconName,
    required this.sortOrder,
    required this.isBuiltIn,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryHiveModel.fromDomain(Category category) {
    return CategoryHiveModel(
      id: category.id,
      name: category.name,
      slug: category.slug.value,
      iconName: category.icon.iconName,
      sortOrder: category.sortOrder,
      isBuiltIn: category.isBuiltIn,
      parentId: category.parentId,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String slug;

  @HiveField(3)
  final String iconName;

  @HiveField(4)
  final int sortOrder;

  @HiveField(5)
  final bool isBuiltIn;

  @HiveField(6)
  final String? parentId;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  Category toDomain() {
    // defensive: icon fallback to other
    final icon = CategoryIconExtension.fromName(iconName);
    // Slug validation - will throw if invalid, but fallback to normalized
    final slugVo = Slug(slug);
    return Category(
      id: id,
      name: name,
      slug: slugVo,
      icon: icon,
      parentId: parentId,
      sortOrder: sortOrder,
      isBuiltIn: isBuiltIn,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  CategoryHiveModel copyWith({
    String? name,
    String? slug,
    String? iconName,
    int? sortOrder,
    bool? isBuiltIn,
    String? parentId,
    bool clearParentId = false,
    DateTime? updatedAt,
  }) {
    return CategoryHiveModel(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
